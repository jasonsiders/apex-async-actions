@SuppressWarnings('PMD.ApexDoc')
public without sharing class AsyncActionLauncher {
	private static final AsyncActionLogger.Adapter LOGGER = AsyncActionLogger.init();

	public Map<String, Id> launch(List<AsyncActionProcessor__mdt> configs) {
		// Get all specified pending Actions by their processor class, and launch each
		Map<String, Id> results = new Map<String, Id>();
		for (PendingAction result : this.queryPendingActions(configs)) {
			String processorName = result?.processorName;
			Id jobId = this.launchJobForProcessor(processorName);
			results?.put(processorName, jobId);
		}
		return results;
	}

	public Id launch(AsyncActionProcessor__mdt config) {
		// Overload launches a single AsyncActionProcessor job
		String processorName = config?.Processor__c;
		return this.launch(new List<AsyncActionProcessor__mdt>{ config })?.get(processorName);
	}

	public Map<String, Id> launchAll() {
		// Create & launch an AsyncActionProcessor job for every AsyncActionConfig__mdt
		List<AsyncActionProcessor__mdt> processors = AsyncActionProcessorService.getAll()?.values();
		return this.launch(processors);
	}

	// **** PRIVATE **** //
	private Set<String> extractProcessorNames(List<AsyncActionProcessor__mdt> configs) {
		Set<String> results = new Set<String>();
		for (AsyncActionProcessor__mdt config : configs) {
			String processorName = config?.Processor__c;
			results?.add(processorName);
		}
		return results;
	}

	@TestVisible
	private AsyncActionProcessor initProcessor(AsyncActionProcessor__mdt config) {
		try {
			return (config?.ProcessorType__c == 'Apex')
				? (AsyncActionProcessor) Type.forName(config?.Processor__c)?.newInstance()
				: new AsyncActionFlowProcessor(config);
		} catch (Exception error) {
			LOGGER?.log(System.LoggingLevel.ERROR, error);
			return null;
		}
	}

	private Id launchJobForProcessor(String processorName) {
		try {
			AsyncActionProcessor__mdt config = AsyncActionProcessorService.get(processorName);
			this.validateJob(config);
			this.validateQueueableLimits();
			AsyncActionProcessor processor = this.initProcessor(config);
			// Use QueueableDuplicateSignature to prevent multiple instances of the same processor job
			System.AsyncOptions options = new System.AsyncOptions();
			options.DuplicateSignature = new System.QueueableDuplicateSignature.Builder()
				?.addString(config?.DeveloperName)
				?.build();
			Id jobId = System.enqueueJob(processor, options);
			String msg = processorName + ': launch() -> ' + jobId;
			LOGGER?.log(System.LoggingLevel.FINEST, msg);
			return jobId;
		} catch (Exception error) {
			String msg = processorName + ' failed to launch: ' + error + '\n' + error?.getStackTraceString();
			LOGGER?.log(System.LoggingLevel.WARN, msg);
			return null;
		}
	}

	private List<PendingAction> queryPendingActions(List<AsyncActionProcessor__mdt> configs) {
		// Retrieves a list of processors w/open actions, in FIFO order
		Set<String> processorNames = this.extractProcessorNames(configs);
		List<AggregateResult> results = [
			SELECT Processor__c processorName
			FROM AsyncAction__c
			WHERE
				Processor__c IN :processorNames
				AND Scheduled__c <= :DateTime.now()
				AND Status__c = :AsyncActionProcessor.Status.PENDING.name()
			WITH SYSTEM_MODE
			GROUP BY Processor__c
			HAVING COUNT(Id) > 0
			ORDER BY MAX(Scheduled__c) ASC // first in, first out!
		];
		// Convert & return the query results in a common format
		return (List<PendingAction>) JSON.deserialize(JSON.serialize(results), List<PendingAction>.class);
	}

	private void validateJob(AsyncActionProcessor__mdt config) {
		// Throws an exception if the current job is disabled
		if (config?.Enabled__c != true) {
			throw new System.AsyncException(config?.DeveloperName + ' is disabled');
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
