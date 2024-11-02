@IsTest
private class AsyncActionStartHandlerTest {
	@IsTest
	static void shouldLaunchAllJobsIfNoneListed() {
		AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionTestUtils.initProcessorSettings(MockAsyncActionProcessor.class);
		AsyncActionProcessor processor = new MockAsyncActionProcessor();
		insert processor?.initAction();
		AsyncActionStart__e event = new AsyncActionStart__e();

		EventBus.publish(event);
		Test.getEventBus().deliver();

		List<AsyncApexJob> jobs = [SELECT Id FROM AsyncApexJob WHERE ApexClass.Name = 'MockAsyncActionProcessor'];
		Assert.isFalse(jobs?.isEmpty(), 'Job(s) were not launched');
	}

	@IsTest
	static void shouldLaunchJobsListedInActions() {
		AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionTestUtils.initProcessorSettings(MockAsyncActionProcessor.class);
		AsyncActionProcessor processor = new MockAsyncActionProcessor();
		insert processor?.initAction();
		AsyncActionStart__e event = new AsyncActionStart__e();
		event.Actions__c = MockAsyncActionProcessor.class?.getName() + ',OtherProcessor,etc';

		EventBus.publish(event);
		Test.getEventBus().deliver();

		List<AsyncApexJob> jobs = [SELECT Id FROM AsyncApexJob WHERE ApexClass.Name = 'MockAsyncActionProcessor'];
		Assert.isFalse(jobs?.isEmpty(), 'Job(s) were not launched');
	}

	@IsTest
	static void shouldNotLaunchJobsIfNotListed() {
		AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionTestUtils.initProcessorSettings(MockAsyncActionProcessor.class);
		AsyncActionProcessor processor = new MockAsyncActionProcessor();
		insert processor?.initAction();
		AsyncActionStart__e event = new AsyncActionStart__e();
		event.Actions__c = 'FakeClass1,FakeClass2,etc';

		EventBus.publish(event);
		Test.getEventBus().deliver();

		List<AsyncApexJob> jobs = [SELECT Id FROM AsyncApexJob WHERE ApexClass.Name = 'MockAsyncActionProcessor'];
		Assert.isTrue(jobs?.isEmpty(), 'Job(s) were launched, but not listed in Actions__c');
	}
}
