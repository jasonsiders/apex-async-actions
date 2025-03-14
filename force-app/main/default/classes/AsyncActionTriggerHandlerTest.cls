@IsTest
private class AsyncActionTriggerHandlerTest {
	@IsTest
	static void shouldLaunchJobsIfTriggerEnabled() {
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		settings.RunOnInsert__c = true;
		AsyncAction__c action = AsyncActions.initAction(settings);

		Database.insert(action, System.AccessLevel.SYSTEM_MODE);
		Test.getEventBus().deliver();

		List<AsyncApexJob> jobs = [
			SELECT Id
			FROM AsyncApexJob
			WHERE ApexClass.Name = :AsyncActionJob.class.getName()
			WITH SYSTEM_MODE
			LIMIT 1
		];
		Assert.isFalse(jobs?.isEmpty(), 'Job(s) were not launched on insert');
	}

	@IsTest
	static void shouldNotLaunchJobsIfTriggerDisabled() {
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		settings.RunOnInsert__c = false;
		AsyncAction__c action = AsyncActions.initAction(settings);

		Database.insert(action, System.AccessLevel.SYSTEM_MODE);
		Test.getEventBus().deliver();

		List<AsyncApexJob> jobs = [
			SELECT Id
			FROM AsyncApexJob
			WHERE ApexClass.Name = :AsyncActionJob.class.getName()
			WITH SYSTEM_MODE
			LIMIT 1
		];
		Assert.isTrue(jobs?.isEmpty(), 'Job(s) were launched on insert');
	}

	@IsTest
	static void shouldScheduleIfEnabled() {
		AsyncActionScheduledJob__mdt jobSettings = AsyncActionTestUtils.initScheduledJobSettings();
		jobSettings.Enabled__c = true;
		jobSettings.Interval__c = 15;
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		AsyncAction__c action = AsyncActions.initAction(settings);

		Database.insert(action, System.AccessLevel.SYSTEM_MODE);
		Test.getEventBus().deliver();

		List<AsyncApexJob> jobs = [
			SELECT Id
			FROM AsyncApexJob
			WHERE ApexClass.Name = :AsyncActionSchedulable.class.getName()
			WITH SYSTEM_MODE
			LIMIT 1
		];
		Assert.isFalse(jobs?.isEmpty(), 'Enabled Scheduled Job was not created');
	}

	@IsTest
	static void shouldScheduleIfDisabled() {
		AsyncActionScheduledJob__mdt jobSettings = AsyncActionTestUtils.initScheduledJobSettings();
		jobSettings.Enabled__c = false;
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		AsyncAction__c action = AsyncActions.initAction(settings);

		Database.insert(action, System.AccessLevel.SYSTEM_MODE);
		Test.getEventBus().deliver();

		List<AsyncApexJob> jobs = [
			SELECT Id
			FROM AsyncApexJob
			WHERE ApexClass.Name = :AsyncActionSchedulable.class.getName()
			WITH SYSTEM_MODE
			LIMIT 1
		];
		Assert.isTrue(jobs?.isEmpty(), 'Disabled Scheduled Job was created');
	}

	@IsTest
	static void shouldDefaultRetriesToConfigIfExists() {
		Type processorType = MockAsyncActionProcessor.class;
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(processorType);
		settings.Retries__c = 5;
		AsyncAction__c action = AsyncActions.initAction(settings);
		action.Retries__c = null;

		Test.startTest();
		Database.insert(action, System.AccessLevel.SYSTEM_MODE);
		Test.stopTest();

		action = [SELECT Id, Retries__c FROM AsyncAction__c WHERE Id = :action.Id];
		Assert.areEqual(settings?.Retries__c, action?.Retries__c, 'Wrong # of Retries');
	}

	@IsTest
	static void shouldDefaultRetriesTo0IfNoConfigExists() {
		AsyncAction__c action = new AsyncAction__c(ProcessorName__c = 'Some_Processor', Retries__c = null);

		Test.startTest();
		Database.insert(action, System.AccessLevel.SYSTEM_MODE);
		Test.stopTest();

		action = [SELECT Id, Retries__c FROM AsyncAction__c WHERE Id = :action.Id];
		Assert.areEqual(0, action?.Retries__c, 'Wrong # of Retries');
	}

	@IsTest
	static void shouldNotOverwriteSetRetriesAmount() {
		Type processorType = MockAsyncActionProcessor.class;
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(processorType);
		settings.Retries__c = 5;
		AsyncAction__c action = AsyncActions.initAction(settings);
		action.Retries__c = 3;

		Test.startTest();
		Database.insert(action, System.AccessLevel.SYSTEM_MODE);
		Test.stopTest();

		action = [SELECT Id, Retries__c FROM AsyncAction__c WHERE Id = :action.Id];
		Assert.areEqual(3, action?.Retries__c, 'Wrong # of Retries');
	}
}
