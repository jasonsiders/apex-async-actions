public without sharing class AsyncActionLauncher {
	/**
	 * This class is responsible for constructing and launching AsyncActionJob queueables
	 * Its `launch` methods will result in a new queueable job if the provided AsyncActionProcessor__mdt object
	 * is active, valid, and has pending AsyncAction__c records associated to it
	 **/
	public Map<String, Id> launch(List<AsyncActionProcessor__mdt> settingsList) {
		// Get all specified pending Actions by their processor class, and launch each
		Map<String, Id> results = new Map<String, Id>{};
		for (PendingAction result : this.queryPendingActions(settingsList)) {
			String processorName = result?.processorName;
			Id jobId = this.launchJobToProcess(processorName);
			results?.put(processorName, jobId);
		}
		return results;
	}

	public Id launch(AsyncActionProcessor__mdt settings) {
		// Overload launches a single AsyncActionJob job
		String processorName = settings?.DeveloperName;
		return this.launch(new List<AsyncActionProcessor__mdt>{ settings })?.get(processorName);
	}

	public Map<String, Id> launchAll() {
		// Create & launch an AsyncActionJob job for every AsyncActionConfig__mdt
		List<AsyncActionProcessor__mdt> all = AsyncActionProcessorService.getAll()?.values();
		return this.launch(all);
	}

	// **** PRIVATE **** //
	private System.QueueableDuplicateSignature buildDuplicateSignature(AsyncActionProcessor__mdt settings) {
		// Build a QueueableDuplicateSigntuare to prevent launching duplicate Queueable jobs
		// Note: Max size of QueueableDuplicateSignature is 32 bytes; hash the processor value to prevent exceeding this value
		Blob hashBlob = Crypto.generateDigest('SHA-256', Blob.valueOf(settings?.DeveloperName));
		String hashHex = EncodingUtil.convertToHex(hashBlob);
		String hashedSignature = hashHex?.substring(0, 32);
		return new System.QueueableDuplicateSignature.Builder()?.addString(hashedSignature)?.build();
	}

	private Set<String> extractDeveloperNamesFrom(List<AsyncActionProcessor__mdt> settingsList) {
		// Extract the DeveloperName from the
		Set<String> results = new Set<String>{};
		for (AsyncActionProcessor__mdt settings : settingsList) {
			String developerName = settings?.DeveloperName;
			results?.add(developerName);
		}
		return results;
	}

	private Integer getMaxStackDepth(AsyncActionProcessor__mdt settings) {
		// Returns the maximum stack depth value defined in the settings
		// Defaults to 5 if none found; this matches the current Queueable defaults
		return (settings?.MaxStackDepth__c)?.intValue() ?? 5;
	}

	private System.AsyncOptions initAsyncOptions(AsyncActionProcessor__mdt settings) {
		// This method defines the AsyncOptions used to enqueue an AsyncActionJob
		System.AsyncOptions options = new System.AsyncOptions();
		// Use QueueableDuplicateSignature to prevent multiple instances of the same processor job
		options.DuplicateSignature = this.buildDuplicateSignature(settings);
		// Set a stack depth using the value defined in the job settings
		options.MaximumQueueableStackDepth = this.getMaxStackDepth(settings);
		return options;
	}

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

	private void validateProcessorSettings(AsyncActionProcessor__mdt settings) {
		// Throws an exception if the current job is disabled
		if (settings?.Enabled__c != true) {
			throw new System.AsyncException(settings?.DeveloperName + ' is disabled');
		}
	}

	private void validateQueueableLimits() {
		// Throws an exception if Queueable limits have been reached
		if (Limits.getQueueableJobs() >= Limits.getLimitQueueableJobs()) {
			throw new System.AsyncException('Reached Queueable job limit: ' + Limits.getQueueableJobs());
		}
	}

	// **** INNER **** //
	public class Factory {
		/**
		 * This class is used to construct AsyncActionJob instances
		 * This pattern forces callers to use the `launch` methdods to create & launch jobs
		 **/
		private AsyncActionProcessor__mdt settings;

		@TestVisible
		private Factory(AsyncActionProcessor__mdt settings) {
			this.settings = settings;
		}

		public AsyncActionProcessor__mdt getSettings() {
			return this.settings;
		}
	}

	private class PendingAction {
		/**
		 * This class is used to store aggregate query results
		 * Its `processorName` points to an AsyncActionProcessor__mdt with related/open Async Actions
		 **/
		public String processorName { get; private set; }
	}
}
