@SuppressWarnings('PMD.ApexDoc')
public abstract without sharing class AsyncActionLauncher {
	static final AsyncActionLogger.Adapter LOGGER = AsyncActionLogger.init();

	public static AsyncActionProcessor initProcessor(AsyncActionProcessor__mdt config) {
		try {
			String processorName = config?.ProcessorClass__c;
			return (AsyncActionProcessor) Type.forName(processorName)?.newInstance();
		} catch (Exception error) {
			LOGGER?.log(System.LoggingLevel.ERROR, error);
			return null;
		}
	}

	public static Map<Type, Id> launchAll(Id currentJobId) {
		// Create & launch an AsyncActionProcessor class for each AsyncActionConfig__mdt
		List<AsyncActionProcessor__mdt> processors = AsyncActionProcessorService.getAll()?.values();
		return AsyncActionLauncher.launchJobs(processors, currentJobId);
	}

	public static Map<Type, Id> launchAll() {
		// Create & launch an AsyncActionProcessor class for each AsyncActionConfig__mdt
		// Use this override when not currently in an AsyncActionProcessor job
		return AsyncActionLauncher.launchAll(null);
	}

	public static Map<Type, Id> launchJobs(List<AsyncActionProcessor__mdt> configs, Id currentJobId) {
		Map<Type, Id> results = new Map<Type, Id>();
		// 1. Map configs by their localized name and type
		Map<String, AsyncActionProcessor__mdt> configsByName = new Map<String, AsyncActionProcessor__mdt>();
		for (AsyncActionProcessor__mdt config : configs) {
			String processorName = config?.ProcessorClass__c;
			configsByName?.put(processorName, config);
		}
		// 2. Get all active jobs related to the processors
		for (AsyncApexJob job : [
			SELECT ApexClass.NamespacePrefix, ApexClass.Name
			FROM AsyncApexJob
			WHERE
				Id != :currentJobId
				AND JobType = 'Queueable'
				AND Status IN ('Holding', 'Queued', 'Preparing', 'Processing')
			WITH SYSTEM_MODE
			ORDER BY CronTrigger.NextFireTime ASC
		]) {
			// Remove the job from contention
			Set<String> parts = new Set<String>{ job?.ApexClass?.NamespacePrefix, job?.ApexClass?.Name };
			parts?.remove(null);
			String className = String.join(parts, '.');
			configsByName?.remove(className);
		}
		// 3. Get all pending Actions by their processor class, and launch each
		for (AggregateResult agg : [
			SELECT ProcessorClass__c className
			FROM AsyncAction__c
			WHERE
				ProcessorClass__c IN :configsByName.keySet()
				AND Scheduled__c <= :DateTime.now()
				AND Status__c = :AsyncActionProcessor.Status.PENDING.name()
			WITH SYSTEM_MODE
			GROUP BY ProcessorClass__c
			HAVING COUNT(Id) > 0
			ORDER BY MAX(Scheduled__c) ASC // first in, first out!
		]) {
			String className = (String) agg?.get('className');
			AsyncActionProcessor__mdt config = configsByName?.get(className);
			AsyncActionProcessor processor = AsyncActionLauncher.initProcessor(config);
			if (AsyncActionLauncher.isLaunchable(processor)) {
				// Launch the job and build the results map w/the resulting job Id
				Id jobId = System.enqueueJob(processor);
				results?.put(processor?.getType(), jobId);
				String msg = processor?.getType() + ': launch() -> ' + jobId;
				LOGGER?.log(System.LoggingLevel.FINEST, msg);
			}
		}
		return results;
	}

	public static Map<Type, Id> launchJobs(AsyncActionProcessor__mdt config, Id currentJobId) {
		return AsyncActionLauncher.launchJobs(new List<AsyncActionProcessor__mdt>{ config }, currentJobId);
	}

	static Boolean isLaunchable(AsyncActionProcessor processor) {
		Boolean canRunQueueable = (Limits.getQueueableJobs() < Limits.getLimitQueueableJobs());
		return canRunQueueable == true && processor?.isEnabled() == true;
	}
}
