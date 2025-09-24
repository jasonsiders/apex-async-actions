/**
 * @description Responsible for constructing and launching AsyncActionJob queueables.
 * Its `launch` methods will result in a new queueable job if the provided AsyncActionProcessor__mdt object
 * is active, valid, and has pending AsyncAction__c records associated to it.
 */
public without sharing class AsyncActionLauncher {
	/**
	 * @description Launches AsyncActionJob queueables for each processor that has pending actions.
	 * @param settingsList List of processor configurations to check for pending actions
	 * @return Map of processor names to their corresponding launched job IDs
	 */
	public Map<String, Id> launch(List<AsyncActionProcessor__mdt> settingsList) {
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
	public Id launch(AsyncActionProcessor__mdt settings) {
		String processorName = settings?.DeveloperName;
		return this.launch(new List<AsyncActionProcessor__mdt>{ settings })?.get(processorName);
	}

	/**
	 * @description Launches AsyncActionJob queueables for all available processor configurations.
	 * @return Map of processor names to their corresponding launched job IDs
	 */
	public Map<String, Id> launchAll() {
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
		// Build a QueueableDuplicateSigntuare to prevent launching duplicate Queueable jobs
		// Note: Max size of QueueableDuplicateSignature is 32 bytes; hash the processor value to prevent exceeding this value
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
		// Extract the DeveloperName from the
		Set<String> results = new Set<String>{};
		for (AsyncActionProcessor__mdt settings : settingsList) {
			String developerName = settings?.DeveloperName;
			results?.add(developerName);
		}
		return results;
	}

	/**
	 * @description Gets the maximum stack depth value from processor settings
	 * @param settings The processor configuration containing stack depth setting
	 * @return Maximum stack depth value, defaults to 5 if not specified
	 */
	private Integer getMaxStackDepth(AsyncActionProcessor__mdt settings) {
		// Returns the maximum stack depth value defined in the settings
		// Defaults to 5 if none found; this matches the current Queueable defaults
		return (settings?.MaxStackDepth__c)?.intValue() ?? 5;
	}

	/**
	 * @description Initializes AsyncOptions for enqueueing AsyncActionJob
	 * @param settings The processor configuration to configure async options for
	 * @return Configured AsyncOptions with duplicate signature and stack depth
	 */
	private System.AsyncOptions initAsyncOptions(AsyncActionProcessor__mdt settings) {
		// This method defines the AsyncOptions used to enqueue an AsyncActionJob
		System.AsyncOptions options = new System.AsyncOptions();
		// Use QueueableDuplicateSignature to prevent multiple instances of the same processor job
		options.DuplicateSignature = this.buildDuplicateSignature(settings);
		// Set a stack depth using the value defined in the job settings
		options.MaximumQueueableStackDepth = this.getMaxStackDepth(settings);
		return options;
	}

	/**
	 * @description Launches an AsyncActionJob for the specified processor name
	 * @param processorName Name of the processor to launch a job for
	 * @return ID of the launched job, or null if launch failed
	 */
	private Id launchJobToProcess(String processorName) {
		// The main/underlying processing method; attempts to launch an AsyncActionJob for the specified processor
		try {
			AsyncActionProcessor__mdt settings = AsyncActionProcessorService.get(processorName);
			// Check that the job is active & valid, and that a queueable can be launched
			this.validateQueueableLimits();
			this.validateProcessorSettings(settings);
			// Construct and launch the job
			System.AsyncOptions options = this.initAsyncOptions(settings);
			AsyncActionLauncher.Factory factory = new AsyncActionLauncher.Factory(settings);
			AsyncActionJob job = new AsyncActionJob(factory);
			Id jobId = System.enqueueJob(job, options);
			// Inspect and return the resulting jobId
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
		// Retrieves a list of processors w/open actions, in FIFO order
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
		// Convert & return the query results in a common format
		return (List<PendingAction>) JSON.deserialize(JSON.serialize(results), List<PendingAction>.class);
	}

	/**
	 * @description Validates that the processor configuration is enabled and ready for use
	 * @param settings The processor configuration to validate
	 */
	private void validateProcessorSettings(AsyncActionProcessor__mdt settings) {
		// Throws an exception if the current job is disabled
		if (settings?.Enabled__c != true) {
			throw new System.AsyncException(settings?.DeveloperName + ' is disabled');
		}
	}

	/**
	 * @description Validates that queueable job limits have not been reached
	 */
	private void validateQueueableLimits() {
		// Throws an exception if Queueable limits have been reached
		if (Limits.getQueueableJobs() >= Limits.getLimitQueueableJobs()) {
			throw new System.AsyncException('Reached Queueable job limit: ' + Limits.getQueueableJobs());
		}
	}

	// **** INNER **** //
	/**
	 * @description Factory class used to construct AsyncActionJob instances.
	 * This pattern forces callers to use the `launch` methods to create & launch jobs.
	 */
	public class Factory {
		/**
		 * @description The processor settings associated with this factory
		 */
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

	/**
	 * @description Used to store aggregate query results for processors with pending actions.
	 * Its `processorName` points to an AsyncActionProcessor__mdt with related/open Async Actions.
	 */
	private class PendingAction {
		/**
		 * @description Name of the processor that has pending actions
		 */
		public String processorName { get; private set; }
	}
}
