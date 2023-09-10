global abstract class AsyncActionLauncher {
    global static AsyncActionProcessor initProcessor(AsyncActionProcessor__mdt config) {
        try {
            String processorName = config?.ProcessorClass__c; 
            return (AsyncActionProcessor) Type.forName(processorName)?.newInstance();
        } catch (Exception error) {
            apxsp.Logger.AdvancedOptions options = new apxsp.Logger.AdvancedOptions().setSource(AsyncActionProcessor.class);
            apxsp.Logger.error(options, error);
            return null; 
        }
    }
    
    global static Map<Type, Id> launchAll() {
        // Create & launch an AsyncActionProcessor class for each AsyncActionConfig__mdt
        List<AsyncActionProcessor__mdt> processors = AsyncActionProcessorService.getAll()?.values();
        return AsyncActionLauncher.launchJobs(processors, null);    
    }

    global static Map<Type, Id> launchJobs(List<AsyncActionProcessor__mdt> configs, Id currentJobId) {
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
            ORDER BY CronTrigger.NextFireTime ASC 
        ]) {
            // Remove the job from contention
            Set<String> parts = new Set<String>{job?.ApexClass?.NamespacePrefix, job?.ApexClass?.Name};
            parts?.remove(null);
            String className = String.join(parts, '.');
            configsByName?.remove(className);
        }
        // 3. Get all pending Actions 
        List<AggregateResult> aggResults = [
            SELECT ProcessorClass__c className
			FROM AsyncAction__c
			WHERE ProcessorClass__c IN :configsByName.keySet() 
                AND Scheduled__c <= :DateTime.now() 
                AND Status__c = :AsyncActionProcessor.Status.PENDING.name()
			GROUP BY ProcessorClass__c
			HAVING COUNT(Id) > 0
			ORDER BY MAX(Scheduled__c) ASC // first in, first out! 
        ];
        for (AggregateResult agg : aggResults) {
            String className = (String) agg?.get('className');
            AsyncActionProcessor__mdt config = configsByName?.get(className);
            AsyncActionProcessor processor = AsyncActionLauncher.initProcessor(config);
            if (AsyncActionLauncher.isLaunchable(processor)) {
				// Launch the job and build the results map w/the resulting job Id
				Id jobId = System.enqueueJob(processor);
				results?.put(processor?.getType(), jobId); 
                apxsp.Logger.AdvancedOptions options = new apxsp.Logger.AdvancedOptions()?.setSource(AsyncActionLauncher.class); 
				apxsp.Logger.finest(options, processor?.getType() + ': launch() -> ' + jobId);
			}
        }
        return results;
    }

    global static Map<Type, Id> launchJobs(AsyncActionProcessor__mdt config, Id currentJobId) {
        return AsyncActionLauncher.launchJobs(new List<AsyncActionProcessor__mdt>{config}, currentJobId);
    }

    static Boolean isLaunchable(AsyncActionProcessor processor) {
        Boolean canRunQueueable = (Limits.getQueueableJobs() < Limits.getLimitQueueableJobs());
        return canRunQueueable == true && processor?.isEnabled() == true;
    }
}