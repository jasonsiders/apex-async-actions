@SuppressWarnings('PMD.AvoidGlobalModifier')
@IsTest
global class AsyncActionTestUtils {
	/**
	 * This class provides global methods to be used to test various parts of the AsyncActions framework
	 **/
	global static AsyncActionGlobalSetting__mdt initGlobalSettings() {
		// Constructs an AsyncActionGlobalSetting__mdt settings object
		// This is usually not necessary, unless testing logging or other plugin(s) behavior
		AsyncActionGlobalSetting__mdt settings = new AsyncActionGlobalSetting__mdt(
			DeveloperName = 'Test_Global_Setting'
		);
		AsyncActionTestUtils.mockGlobalSettings(settings);
		return settings;
	}

	global static AsyncActionProcessor__mdt initApexProcessor(Type processorType) {
		// Instantiates & returns an Apex processor settings object with default values for testing
		String className = processorType?.getName();
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initFlowProcessor(className);
		settings.ProcessorType__c = 'Apex';
		return settings;
	}

	global static AsyncActionProcessor__mdt initFlowProcessor(String flowName) {
		// Instantiates & returns a Flow processor settings object with default values for testing
		AsyncActionProcessor__mdt settings = new AsyncActionProcessor__mdt(
			BatchSize__c = 200,
			DeveloperName = 'Test_' + flowName,
			Enabled__c = true,
			MasterLabel = 'Test ' + flowName,
			Processor__c = flowName,
			ProcessorType__c = 'Flow',
			Retries__c = 3,
			RetryInterval__c = 3,
			RunOnInsert__c = false
		);
		AsyncActionTestUtils.mockProcessorSettings(settings);
		return settings;
	}

	global static AsyncActionScheduledJob__mdt initScheduledJobSettings() {
		// Instantiates and returns a scheduled job settings w/default values for testing
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
		// Instantiates and returns a scheduled job item settings w/default values for testing
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
		// Gives @IsTest access to inject global settings record(s) to external callers
		AsyncActionGlobalSettingService.settings = settings;
	}

	global static void mockProcessorSettings(AsyncActionProcessor__mdt settings) {
		// Gives @IsTest access to inject settings records to external callers
		AsyncActionProcessorService.processors = (AsyncActionProcessorService.processors != null)
			? AsyncActionProcessorService.processors
			: new Map<String, AsyncActionProcessor__mdt>();
		String processorName = settings?.DeveloperName;
		AsyncActionProcessorService.processors?.put(processorName, settings);
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
}
