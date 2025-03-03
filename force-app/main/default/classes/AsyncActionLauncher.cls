@SuppressWarnings('PMD.ApexDoc')
public abstract without sharing class AsyncActionLauncher {
	private static final String CLASS_NAME_PARAMETER = 'className';
	private static final AsyncActionLogger.Adapter LOGGER = AsyncActionLogger.init();
	private static Map<String, AsyncActionProcessor__mdt> configsByName;
	private static Map<Type, Id> results;

	public static AsyncActionProcessor initProcessor(AsyncActionProcessor__mdt config) {
		try {
			String processorName = config?.Processor__c;
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
		AsyncActionLauncher.results = new Map<Type, Id>();
		// 1. Map configs by their localized name and type
		AsyncActionLauncher.configsByName = AsyncActionLauncher.mapConfigsByName(configs);
		// 2. Get all active jobs related to the processors
		List<AsyncApexJob> activeJobs = AsyncActionLauncher.queryActiveJobs(currentJobId);
		AsyncActionLauncher.removeActiveJobs(activeJobs);
		// 3. Get all pending Actions by their processor class, and launch each
		for (AggregateResult agg : AsyncActionLauncher.queryAggregateActions()) {
			String processorClass = (String) agg?.get('className');
			AsyncActionLauncher.launchJobForProcessor(processorClass);
		}
		return AsyncActionLauncher.results;
	}

	public static Map<Type, Id> launchJobs(AsyncActionProcessor__mdt config, Id currentJobId) {
		return AsyncActionLauncher.launchJobs(new List<AsyncActionProcessor__mdt>{ config }, currentJobId);
	}

	private static Boolean isLaunchable(AsyncActionProcessor processor) {
		Boolean canRunQueueable = (Limits.getQueueableJobs() < Limits.getLimitQueueableJobs());
		return canRunQueueable == true && processor?.isEnabled() == true;
	}

	private static void launchJobForProcessor(String processorClass) {
		AsyncActionProcessor__mdt config = AsyncActionLauncher.configsByName?.get(processorClass);
		AsyncActionProcessor processor = AsyncActionLauncher.initProcessor(config);
		if (AsyncActionLauncher.isLaunchable(processor)) {
			// Launch the job and build the results map w/the resulting job Id
			Id jobId = System.enqueueJob(processor);
			AsyncActionLauncher.results?.put(processor?.getType(), jobId);
			String msg = processor?.getType() + ': launch() -> ' + jobId;
			LOGGER?.log(System.LoggingLevel.FINEST, msg);
		}
	}

	private static Map<String, AsyncActionProcessor__mdt> mapConfigsByName(List<AsyncActionProcessor__mdt> configs) {
		Map<String, AsyncActionProcessor__mdt> configsByName = new Map<String, AsyncActionProcessor__mdt>();
		for (AsyncActionProcessor__mdt config : configs) {
			String processorName = config?.Processor__c;
			configsByName?.put(processorName, config);
		}
		return configsByName;
	}

	private static List<AsyncApexJob> queryActiveJobs(id currentJobId) {
		return [
			SELECT ApexClass.NamespacePrefix, ApexClass.Name
			FROM AsyncApexJob
			WHERE
				Id != :currentJobId
				AND JobType = 'Queueable'
				AND Status IN ('Holding', 'Queued', 'Preparing', 'Processing')
			WITH SYSTEM_MODE
			ORDER BY CronTrigger.NextFireTime ASC
		];
	}

	private static List<AggregateResult> queryAggregateActions() {
		Set<String> configNames = AsyncActionLauncher.configsByName?.keySet() ?? new Set<String>();
		return [
			SELECT Processor__c className
			FROM AsyncAction__c
			WHERE
				Processor__c IN :configNames
				AND Scheduled__c <= :DateTime.now()
				AND Status__c = :AsyncActionProcessor.Status.PENDING.name()
			WITH SYSTEM_MODE
			GROUP BY Processor__c
			HAVING COUNT(Id) > 0
			ORDER BY MAX(Scheduled__c) ASC // first in, first out!
		];
	}

	private static void removeActiveJobs(List<AsyncApexJob> jobs) {
		// Remove each AsyncApexJob's corresponding processor config from the map of configs to be launched
		for (AsyncApexJob job : jobs) {
			// Remove the job from contention
			Set<String> parts = new Set<String>{ job?.ApexClass?.NamespacePrefix, job?.ApexClass?.Name };
			parts?.remove(null);
			String className = String.join(parts, '.');
			AsyncActionLauncher.configsByName?.remove(className);
		}
	}
}
