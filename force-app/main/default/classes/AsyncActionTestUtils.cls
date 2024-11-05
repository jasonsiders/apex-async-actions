@SuppressWarnings('PMD.ApexDoc, PMD.AvoidGlobalModifier')
@IsTest
global class AsyncActionTestUtils {
	global static AsyncActionGlobalSetting__mdt initGlobalSettings() {
		AsyncActionGlobalSetting__mdt settings = new AsyncActionGlobalSetting__mdt(
			DeveloperName = 'Test_Global_Setting'
		);
		AsyncActionTestUtils.mockGlobalSettings(settings);
		return settings;
	}

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
		Integer numSettings = jobNames?.size() ?? 0;
		String jobName = 'TestJob_' + (numSettings + 1);
		AsyncActionScheduledJob__mdt settings = new AsyncActionScheduledJob__mdt(
			DeveloperName = jobName,
			Enabled__c = false,
			MasterLabel = jobName,
			Type__c = 'Hourly'
		);
		AsyncActionTestUtils.mockScheduledJobSettings(settings);
		return settings;
	}

	global static AsyncActionScheduledJobItem__mdt initScheduledJobItem(
		AsyncActionProcessor__mdt actionSettings,
		AsyncActionScheduledJob__mdt jobSettings
	) {
		AsyncActionScheduledJobItem__mdt item = new AsyncActionScheduledJobItem__mdt(
			AsyncActionProcessor__r = actionSettings,
			DeveloperName = actionSettings?.DeveloperName + '_' + jobSettings?.DeveloperName,
			Enabled__c = true,
			ScheduledJob__r = jobSettings
		);
		AsyncActionTestUtils.mockScheduledJobItem(item);
		return item;
	}

	global static void mockGlobalSettings(AsyncActionGlobalSetting__mdt settings) {
		AsyncActionGlobalSettingService.settings = settings;
	}

	global static void mockProcessorSettings(AsyncActionProcessor__mdt processor) {
		// Gives @IsTest access to inject settings records to external callers
		AsyncActionProcessorService.processors = (AsyncActionProcessorService.processors != null)
			? AsyncActionProcessorService.processors
			: new Map<String, AsyncActionProcessor__mdt>();
		String processorName = processor?.ProcessorClass__c;
		AsyncActionProcessorService.processors?.put(processorName, processor);
	}

	global static void mockScheduledJobItem(AsyncActionScheduledJobItem__mdt item) {
		// Gives @IsTest access to inject settings records to external callers
		// **IMPORTANT**: The input object must have a fully populated ScheduledJob__r relationship
		String jobName = item?.ScheduledJob__r?.DeveloperName;
		List<AsyncActionScheduledJobItem__mdt> matching = AsyncActionScheduledJobItemService.jobItems
				?.containsKey(jobName)
			? AsyncActionScheduledJobItemService.jobItems?.get(jobName)
			: new List<AsyncActionScheduledJobItem__mdt>();
		matching?.add(item);
		AsyncActionScheduledJobItemService.jobItems?.put(jobName, matching);
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
