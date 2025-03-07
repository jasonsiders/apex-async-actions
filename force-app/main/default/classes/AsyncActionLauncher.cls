@SuppressWarnings('PMD.ApexDoc')
public without sharing class AsyncActionLauncher {
	public Map<String, Id> launch(List<AsyncActionProcessor__mdt> settings) {
		// Get all specified pending Actions by their processor class, and launch each
		Map<String, Id> results = new Map<String, Id>();
		for (PendingAction result : this.queryPendingActions(settings)) {
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
		List<AsyncActionProcessor__mdt> processors = AsyncActionProcessorService.getAll()?.values();
		return this.launch(processors);
	}

	// **** PRIVATE **** //
	private System.QueueableDuplicateSignature buildDuplicateSignature(AsyncActionProcessor__mdt settings) {
		// Build a QueueableDuplicateSigntuare to prevent launching duplicate Queueable jobs
		String hashedSignature = this.hashProcessorName(settings);
		return new System.QueueableDuplicateSignature.Builder()?.addString(hashedSignature)?.build();
	}

	private Set<String> extractProcessorNames(List<AsyncActionProcessor__mdt> configs) {
		Set<String> results = new Set<String>();
		for (AsyncActionProcessor__mdt settings : configs) {
			String processorName = settings?.DeveloperName;
			results?.add(processorName);
		}
		return results;
	}

	private String hashProcessorName(AsyncActionProcessor__mdt settings) {
		// Note: Max size of QueueableDuplicateSignature is32 bytes; hash the processor value to prevent exceeding this value
		Blob hashBlob = Crypto.generateDigest('SHA-256', Blob.valueOf(settings?.DeveloperName));
		String hashHex = EncodingUtil.convertToHex(hashBlob);
		return hashHex?.substring(0, 32);
	}

	private Id launchJobToProcess(String processorName) {
		try {
			AsyncActionProcessor__mdt settings = AsyncActionProcessorService.get(processorName);
			this.validateJob(settings);
			this.validateQueueableLimits();
			// Use QueueableDuplicateSignature to prevent multiple instances of the same processor job
			System.AsyncOptions options = new System.AsyncOptions();
			options.DuplicateSignature = this.buildDuplicateSignature(settings);
			Id jobId = System.enqueueJob(new AsyncActionJob(settings), options);
			AsyncActionLogger.log(System.LoggingLevel.FINEST, processorName + ': launch() -> ' + jobId);
			return jobId;
		} catch (Exception error) {
			String msg = processorName + ' failed to launch: ' + error + '\n' + error?.getStackTraceString();
			AsyncActionLogger.log(System.LoggingLevel.WARN, msg);
			return null;
		}
	}

	private List<PendingAction> queryPendingActions(List<AsyncActionProcessor__mdt> configs) {
		// Retrieves a list of processors w/open actions, in FIFO order
		Set<String> processorNames = this.extractProcessorNames(configs);
		List<AggregateResult> results = [
			SELECT ProcessorName__c processorName
			FROM AsyncAction__c
			WHERE
				ProcessorName__c IN :processorNames
				AND NextEligibleAt__c <= :DateTime.now()
				AND Status__c = :AsyncActionJob.Status.PENDING.name()
			WITH SYSTEM_MODE
			GROUP BY ProcessorName__c
			HAVING COUNT(Id) > 0
			ORDER BY MAX(NextEligibleAt__c) ASC // first in, first out!
		];
		// Convert & return the query results in a common format
		return (List<PendingAction>) JSON.deserialize(JSON.serialize(results), List<PendingAction>.class);
	}

	private void validateJob(AsyncActionProcessor__mdt settings) {
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
	private class PendingAction {
		// This class is used to store aggregate query results
		// Its `processorName` points to an AsyncActionProcessor__mdt with related/open Async Actions
		public String processorName { get; private set; }
	}
}
