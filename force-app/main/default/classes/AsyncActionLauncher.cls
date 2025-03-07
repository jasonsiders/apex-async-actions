@SuppressWarnings('PMD.ApexDoc')
public without sharing class AsyncActionLauncher {
	public Map<String, Id> launch(List<AsyncActionProcessor__mdt> configs) {
		// Get all specified pending Actions by their processor class, and launch each
		Map<String, Id> results = new Map<String, Id>();
		for (PendingAction result : this.queryPendingActions(configs)) {
			System.debug('@jason: Result: ' + result);
			String processorName = result?.processorName;
			Id jobId = this.launchJobForProcessor(processorName);
			results?.put(processorName, jobId);
		}
		return results;
	}

	public Id launch(AsyncActionProcessor__mdt settings) {
		// Overload launches a single AsyncActionProcessor job
		String processorName = settings?.DeveloperName;
		return this.launch(new List<AsyncActionProcessor__mdt>{ settings })?.get(processorName);
	}

	public Map<String, Id> launchAll() {
		// Create & launch an AsyncActionProcessor job for every AsyncActionConfig__mdt
		List<AsyncActionProcessor__mdt> processors = AsyncActionProcessorService.getAll()?.values();
		return this.launch(processors);
	}

	// **** PRIVATE **** //
	private Set<String> extractProcessorNames(List<AsyncActionProcessor__mdt> configs) {
		Set<String> results = new Set<String>();
		for (AsyncActionProcessor__mdt settings : configs) {
			String processorName = settings?.DeveloperName;
			results?.add(processorName);
		}
		return results;
	}

	@TestVisible
	private AsyncActionProcessor initProcessor(AsyncActionProcessor__mdt settings) {
		try {
			return (AsyncActionProcessor) Type.forName(settings?.Processor__c)?.newInstance();
		} catch (Exception error) {
			AsyncActionLogger.log(System.LoggingLevel.ERROR, error);
			return null;
		}
	}

	private Id launchJobForProcessor(String processorName) {
		try {
			AsyncActionProcessor__mdt settings = AsyncActionProcessorService.get(processorName);
			System.debug('@jason: launchJobForProcessorName: ' + processorName + ' -> ' + settings);
			System.debug('@jason: All settings: ' + JSON.serializePretty(AsyncActionProcessorService.getAll()));
			this.validateJob(settings);
			this.validateQueueableLimits();
			AsyncActionProcessor processor = this.initProcessor(settings);
			// Use QueueableDuplicateSignature to prevent multiple instances of the same processor job
			System.AsyncOptions options = new System.AsyncOptions();
			options.DuplicateSignature = new System.QueueableDuplicateSignature.Builder()
				?.addString(settings?.DeveloperName)
				?.build();
			Id jobId = System.enqueueJob(processor, options);
			String msg = processorName + ': launch() -> ' + jobId;
			AsyncActionLogger.log(System.LoggingLevel.FINEST, msg);
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
				AND Scheduled__c <= :DateTime.now()
				AND Status__c = :AsyncActionProcessor.Status.PENDING.name()
			WITH SYSTEM_MODE
			GROUP BY ProcessorName__c
			HAVING COUNT(Id) > 0
			ORDER BY MAX(Scheduled__c) ASC // first in, first out!
		];
		// Convert & return the query results in a common format
		System.debug('@jason: queryPendingActions: ' + JSON.serialize(results));
		System.debug(
			'@jason: all async actions: ' + JSON.serialize([SELECT Id, ProcessorName__c, Status__c FROM AsyncAction__c])
		);
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

	private class PendingAction {
		// This class is used to store aggregate query results
		// Its `processorName` points to an AsyncActionProcessor__mdt with related/open Async Actions
		public String processorName { get; private set; }
	}
}
