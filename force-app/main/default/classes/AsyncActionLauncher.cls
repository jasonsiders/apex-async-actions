/** @description Responsible for constructing and launching AsyncActionJob queueables. Its `launch` methods will result in a new queueable job if the provided AsyncActionProcessor__mdt is active, valid, and has pending AsyncAction__c records. **/
// Unlocked package public API requires global visibility for external subscriber access
@SuppressWarnings('PMD.AvoidGlobalModifier')
global without sharing class AsyncActionLauncher {
	// **** PUBLIC **** //
	/**
	 * @description Launches AsyncActionJob queueables for each processor that has pending actions.
	 * @param settingsList List of processor configurations to check for pending actions
	 * @return Map of processor names to their corresponding launched job IDs
	 */
	global Map<String, Id> launch(List<AsyncActionProcessor__mdt> settingsList) {
		Map<String, Id> results = new Map<String, Id>{};
		for (PendingAction result : this.queryPendingActions(settingsList)) {
			String processorName = result?.processorName;
			Id jobId = this.launchJobToProcess(processorName);
			results?.put(processorName, jobId);
		}
		return results;
	}

	/**
	 * @description Launches a single AsyncActionJob for the specified processor configuration.
	 * @param settings The processor configuration to launch a job for
	 * @return The ID of the launched job, or null if no job was launched
	 */
	global Id launch(AsyncActionProcessor__mdt settings) {
		String processorName = settings?.DeveloperName;
		return this.launch(new List<AsyncActionProcessor__mdt>{ settings })?.get(processorName);
	}

	/**
	 * @description Launches AsyncActionJob queueables for all available processor configurations.
	 * @return Map of processor names to their corresponding launched job IDs
	 */
	global Map<String, Id> launchAll() {
		List<AsyncActionProcessor__mdt> all = AsyncActionProcessorService.getAll()?.values();
		return this.launch(all);
	}

	// **** PRIVATE **** //
	/**
	 * @description Builds a QueueableDuplicateSignature to prevent launching duplicate queueable jobs
	 * @param settings The processor configuration to create a signature for
	 * @return A QueueableDuplicateSignature based on the processor's developer name
	 */
	private System.QueueableDuplicateSignature buildDuplicateSignature(AsyncActionProcessor__mdt settings) {
		// Max size of QueueableDuplicateSignature is 32 bytes; hash the processor name to stay within that limit
		Blob hashBlob = Crypto.generateDigest('SHA-256', Blob.valueOf(settings?.DeveloperName));
		String hashHex = EncodingUtil.convertToHex(hashBlob);
		String hashedSignature = hashHex?.substring(0, 32);
		return new System.QueueableDuplicateSignature.Builder()?.addString(hashedSignature)?.build();
	}

	/**
	 * @description Extracts developer names from a list of processor configurations
	 * @param settingsList List of processor configurations to extract names from
	 * @return Set of developer names from the processor configurations
	 */
	private Set<String> extractDeveloperNamesFrom(List<AsyncActionProcessor__mdt> settingsList) {
		Set<String> results = new Set<String>{};
		for (AsyncActionProcessor__mdt settings : settingsList) {
			String developerName = settings?.DeveloperName;
			results?.add(developerName);
		}
		return results;
	}

	/**
	 * @description Gets the delay in minutes before enqueueing a job for the given processor.
	 * Processor-level setting takes priority over global setting; defaults to 0.
	 * @param settings The processor configuration to check for delay setting
	 * @return Delay in minutes to use when enqueueing the job
	 */
	@TestVisible
	private Integer getDelayInMinutes(AsyncActionProcessor__mdt settings) {
		Decimal delay = settings?.DelayInMinutes__c ?? AsyncActionGlobalSettingService.getSettings()?.DelayInMinutes__c;
		return delay?.intValue() ?? 0;
	}

	/**
	 * @description Gets the maximum stack depth value from processor settings
	 * @param settings The processor configuration containing stack depth setting
	 * @return Maximum stack depth value, defaults to 5 if not specified
	 */
	private Integer getMaxStackDepth(AsyncActionProcessor__mdt settings) {
		// Defaults to 5 to match the Salesforce Queueable platform default
		return (settings?.MaxStackDepth__c)?.intValue() ?? 5;
	}

	/**
	 * @description Initializes AsyncOptions for enqueueing AsyncActionJob
	 * @param settings The processor configuration to configure async options for
	 * @return Configured AsyncOptions with duplicate signature, stack depth, and delay
	 */
	private System.AsyncOptions initAsyncOptions(AsyncActionProcessor__mdt settings) {
		System.AsyncOptions options = new System.AsyncOptions();
		// DuplicateSignature prevents multiple instances of the same processor from running concurrently
		options.DuplicateSignature = this.buildDuplicateSignature(settings);
		options.MaximumQueueableStackDepth = this.getMaxStackDepth(settings);
		// Always specify a delay to avoid being buffered by org-wide default delay settings
		options.minimumQueueableDelayInMinutes = this.getDelayInMinutes(settings);
		return options;
	}

	/**
	 * @description Launches an AsyncActionJob for the specified processor name
	 * @param processorName Name of the processor to launch a job for
	 * @return ID of the launched job, or null if launch failed
	 */
	private Id launchJobToProcess(String processorName) {
		try {
			AsyncActionProcessor__mdt settings = AsyncActionProcessorService.get(processorName);
			this.validateQueueableLimits();
			this.validateProcessorSettings(settings);
			System.AsyncOptions options = this.initAsyncOptions(settings);
			AsyncActionLauncher.Factory factory = new AsyncActionLauncher.Factory(settings);
			AsyncActionJob job = new AsyncActionJob(factory);
			Id jobId = System.enqueueJob(job, options);
			AsyncActionLogger.log(System.LoggingLevel.FINEST, processorName + ': launch() -> ' + jobId);
			return jobId;
		} catch (Exception error) {
			String msg = processorName + ' failed to launch: ' + error + '\n' + error?.getStackTraceString();
			AsyncActionLogger.log(System.LoggingLevel.WARN, msg);
			return null;
		}
	}

	/**
	 * @description Queries for processors that have pending actions ready for processing
	 * @param settingsList List of processor configurations to check for pending actions
	 * @return List of PendingAction objects representing processors with pending work
	 */
	private List<PendingAction> queryPendingActions(List<AsyncActionProcessor__mdt> settingsList) {
		List<AggregateResult> results = [
			SELECT ProcessorName__c processorName
			FROM AsyncAction__c
			WHERE
				ProcessorName__c IN :this.extractDeveloperNamesFrom(settingsList)
				AND NextEligibleAt__c <= :DateTime.now()
				AND Status__c = :AsyncActions.Status.PENDING.name()
			WITH SYSTEM_MODE
			GROUP BY ProcessorName__c
			HAVING COUNT(Id) > 0
			ORDER BY MAX(NextEligibleAt__c) ASC // first in, first out!
		];
		String serialized = JSON.serialize(results);
		return (List<PendingAction>) JSON.deserialize(serialized, List<PendingAction>.class);
	}

	/**
	 * @description Validates that the processor configuration is enabled and ready for use
	 * @param settings The processor configuration to validate
	 */
	private void validateProcessorSettings(AsyncActionProcessor__mdt settings) {
		if (settings?.Enabled__c != true) {
			throw new System.AsyncException(settings?.DeveloperName + ' is disabled');
		}
	}

	/** @description Validates that queueable job limits have not been reached **/
	private void validateQueueableLimits() {
		if (Limits.getQueueableJobs() >= Limits.getLimitQueueableJobs()) {
			throw new System.AsyncException('Reached Queueable job limit: ' + Limits.getQueueableJobs());
		}
	}

	// **** INNER **** //
	/** @description Factory class used to construct AsyncActionJob instances. Callers must use the `launch` methods rather than constructing jobs directly. **/
	public class Factory {
		/** @description The processor settings associated with this factory **/
		private AsyncActionProcessor__mdt settings;

		/**
		 * @description Test visible constructor for the Factory class
		 * @param settings The processor configuration to associate with this factory
		 */
		@TestVisible
		private Factory(AsyncActionProcessor__mdt settings) {
			this.settings = settings;
		}

		/**
		 * @description Returns the processor settings associated with this factory.
		 * @return The AsyncActionProcessor__mdt settings for this factory
		 */
		public AsyncActionProcessor__mdt getSettings() {
			return this.settings;
		}
	}

	/** @description Wraps aggregate query results for processors with pending actions. Its `processorName` maps to an AsyncActionProcessor__mdt with open AsyncAction__c records. **/
	private class PendingAction {
		/** @description Name of the processor that has pending actions **/
		public String processorName { get; private set; }
	}
}
