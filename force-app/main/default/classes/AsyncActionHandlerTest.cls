@IsTest
private class AsyncActionHandlerTest {
	@IsTest
	static void shouldLaunchJobsIfTriggerEnabled() {
		AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(MockAsyncActionProcessor.class);
		config.RunOnInsert__c = true;
		AsyncActionProcessor processor = new MockAsyncActionProcessor();
		AsyncAction__c action = processor?.initAction(null);

		insert action;
		Test.getEventBus().deliver();

		List<AsyncApexJob> jobs = [
			SELECT Id
			FROM AsyncApexJob
			WHERE ApexClass.Name = 'MockAsyncActionProcessor'
			LIMIT 1
		];
		Assert.isFalse(jobs?.isEmpty(), 'Job(s) were not launched on insert');
	}

	@IsTest
	static void shouldNotLaunchJobsIfTriggerDisabled() {
		AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(MockAsyncActionProcessor.class);
		config.RunOnInsert__c = false;
		AsyncActionProcessor processor = new MockAsyncActionProcessor();
		AsyncAction__c action = processor?.initAction(null);

		insert action;
		Test.getEventBus().deliver();

		List<AsyncApexJob> jobs = [
			SELECT Id
			FROM AsyncApexJob
			WHERE ApexClass.Name = 'MockAsyncActionProcessor'
			LIMIT 1
		];
		Assert.isTrue(jobs?.isEmpty(), 'Job(s) were launched on insert');
	}

	@IsTest
	static void shouldScheduleIfEnabled() {
		AsyncActionScheduledJob__mdt jobSettings = AsyncActionTestUtils.initScheduledJobSettings();
		jobSettings.Enabled__c = true;
		jobSettings.Interval__c = 15;
		AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(MockAsyncActionProcessor.class);
		AsyncActionProcessor processor = new MockAsyncActionProcessor();
		AsyncAction__c action = processor?.initAction(null);

		insert action;
		Test.getEventBus().deliver();

		List<AsyncApexJob> jobs = [SELECT Id FROM AsyncApexJob WHERE ApexClass.Name = 'AsyncActionSchedulable' LIMIT 1];
		Assert.isFalse(jobs?.isEmpty(), 'Enabled Scheduled Job was not created');
	}

	@IsTest
	static void shouldScheduleIfDisabled() {
		AsyncActionScheduledJob__mdt jobSettings = AsyncActionTestUtils.initScheduledJobSettings();
		jobSettings.Enabled__c = false;
		AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(MockAsyncActionProcessor.class);
		AsyncActionProcessor processor = new MockAsyncActionProcessor();
		AsyncAction__c action = processor?.initAction(null);

		insert action;
		Test.getEventBus().deliver();

		List<AsyncApexJob> jobs = [SELECT Id FROM AsyncApexJob WHERE ApexClass.Name = 'AsyncActionSchedulable' LIMIT 1];
		Assert.isTrue(jobs?.isEmpty(), 'Disabled Scheduled Job was created');
	}
}
