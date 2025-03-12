@IsTest
private class AsyncActionStartTriggerHandlerTest {
	@IsTest
	static void shouldLaunchAllJobsIfNoneListed() {
		AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		AsyncAction__c action = AsyncActions.initAction(settings);
		Database.insert(action, System.AccessLevel.SYSTEM_MODE);
		AsyncActionStart__e event = new AsyncActionStart__e();

		EventBus.publish(event);
		Test.getEventBus().deliver();

		List<AsyncApexJob> jobs = [
			SELECT Id
			FROM AsyncApexJob
			WHERE ApexClass.Name = :AsyncActionJob.class.getName()
			WITH SYSTEM_MODE
		];
		Assert.isFalse(jobs?.isEmpty(), 'Job(s) were not launched');
	}

	@IsTest
	static void shouldLaunchJobsListedInActions() {
		AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		AsyncAction__c action = AsyncActions.initAction(settings);
		Database.insert(action, System.AccessLevel.SYSTEM_MODE);
		AsyncActionStart__e event = new AsyncActionStart__e();
		event.Actions__c = settings?.DeveloperName + ',Other_Processor,etc';

		Test.startTest();
		EventBus.publish(event);
		Test.getEventBus().deliver();
		Test.stopTest();

		List<AsyncApexJob> jobs = [
			SELECT Id
			FROM AsyncApexJob
			WHERE ApexClass.Name = :AsyncActionJob.class.getName()
			WITH SYSTEM_MODE
		];
		Assert.areEqual(1, jobs?.size(), 'Job was not launched');
	}

	@IsTest
	static void shouldNotLaunchJobsIfNotListed() {
		AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		AsyncAction__c action = AsyncActions.initAction(settings);
		Database.insert(action, System.AccessLevel.SYSTEM_MODE);
		AsyncActionStart__e event = new AsyncActionStart__e();
		event.Actions__c = 'FakeClass1,FakeClass2,etc';

		EventBus.publish(event);
		Test.getEventBus().deliver();

		List<AsyncApexJob> jobs = [
			SELECT Id
			FROM AsyncApexJob
			WHERE ApexClass.Name = :AsyncActionJob.class.getName()
			WITH SYSTEM_MODE
		];
		Assert.isTrue(jobs?.isEmpty(), 'Job(s) were launched, but not listed in Actions__c');
	}
}
