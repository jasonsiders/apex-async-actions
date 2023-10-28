@IsTest
global class AsyncActionTestUtils {
	global static AsyncActionProcessor__mdt initProcessorSettings(Type processorType) {
		// Instantiates & returns a processor settings object with default values for testing
		AsyncActionProcessor__mdt processor = new AsyncActionProcessor__mdt(
			BatchSize__c = 200,
			DeveloperName = 'Test_' + processorType?.getName(),
			Enabled__c = true,
			MasterLabel = 'Test ' + processorType?.getName(),
			ProcessorClass__c = processorType?.getName(),
			Retries__c = 3,
			RetryInterval__c = 3,
			RunOnInsert__c = false
		);
		AsyncActionTestUtils.mockProcessorSettings(processor);
		return processor;
	}

	global static AsyncActionScheduledJob__mdt initScheduledJobSettings() {
		// Instantiates and returns a processor settings object w/default values for testing
		Set<String> jobNames = AsyncActionScheduledJobService.settings?.keySet();
		Integer numSettings = jobNames != null ? jobNames?.size() : 0;
		String jobName = 'TestJob_' + (numSettings + 1);
		AsyncActionScheduledJob__mdt settings = new AsyncActionScheduledJob__mdt(
			DeveloperName = jobName,
			Enabled__c = false, 
			Interval__c = 60,
			MasterLabel = jobName
		); 
		AsyncActionTestUtils.mockScheduledJobSettings(settings);
		return settings;
	}

	global static void mockProcessorSettings(AsyncActionProcessor__mdt processor) {
		// Gives @IsTest access to inject settings records to external callers
		AsyncActionProcessorService.processors = (AsyncActionProcessorService.processors != null)
			? AsyncActionProcessorService.processors
			: new Map<String, AsyncActionProcessor__mdt>();
		String processorName = processor?.ProcessorClass__c;
		AsyncActionProcessorService.processors?.put(processorName, processor);
	}

	global static void mockScheduledJobSettings(AsyncActionScheduledJob__mdt jobSettings) {
		// Gives @IsTest access to inject job settings records to external callers
		AsyncActionScheduledJobService.settings = (AsyncActionScheduledJobService.settings != null)
			? AsyncActionScheduledJobService.settings
			: new Map<String, AsyncActionScheduledJob__mdt>();
		String jobName = jobSettings?.DeveloperName;
		AsyncActionScheduledJobService.settings?.put(jobName, jobSettings);
	}

	global static void setAllowRecursion(Boolean allowRecursion) {
		// Enables external callers to manipulate the @TestVisible allowRecursion flag
		// This is disabled in @IsTest context by default, to simplify testing and prevent runaways
		AsyncActionProcessor.allowRecursion = allowRecursion;
	}
}
