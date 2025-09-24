@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class AsyncActionLauncherTest {
	@IsTest
	static void shouldLaunchAllJobs() {
		Type processorType = MockAsyncActionProcessor.class;
		AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(processorType);
		AsyncAction__c action = AsyncActions.initAction(settings);
		Database.insert(action, System.AccessLevel.SYSTEM_MODE);

		Test.startTest();
		new AsyncActionLauncher()?.launchAll();
		Test.stopTest();

		Assert.areEqual(1, AsyncActionLauncherTest.getNumAsyncJobs(), 'Wrong # of jobs launched');
	}

	@IsTest
	static void shouldLaunchSpecifiedJobs() {
		Type processorType = MockAsyncActionProcessor.class;
		AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(processorType);
		AsyncAction__c action = AsyncActions.initAction(settings);
		Database.insert(action, System.AccessLevel.SYSTEM_MODE);

		Test.startTest();
		Id jobId = new AsyncActionLauncher()?.launch(settings);
		Test.stopTest();

		Assert.isNotNull(jobId, 'A job was not launched');
	}

	@IsTest
	static void shouldNotLaunchInvalidJob() {
		Type fakeProcessorType = Account.class; // Obv not a real processor!
		AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(fakeProcessorType);
		AsyncAction__c action = AsyncActions.initAction(settings);
		Database.insert(action, System.AccessLevel.SYSTEM_MODE);

		Test.startTest();
		new AsyncActionLauncher()?.launchAll();
		Test.stopTest();

		Assert.areEqual(0, AsyncActionLauncherTest.getNumAsyncJobs(), 'Launched job for invalid processor');
	}

	@IsTest
	static void shouldNotLaunchIfDisabled() {
		Type processorType = MockAsyncActionProcessor.class;
		AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(processorType);
		settings.Enabled__c = false;
		AsyncAction__c action = AsyncActions.initAction(settings);
		Database.insert(action, System.AccessLevel.SYSTEM_MODE);

		Test.startTest();
		Id jobId = new AsyncActionLauncher()?.launch(settings);
		Test.stopTest();

		Assert.isNull(jobId, 'Launched disabled job');
	}

	@SuppressWarnings('PMD.OperationWithLimitsInLoop')
	@IsTest
	static void shouldNotLaunchIfQueueableLimitsExceeded() {
		AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		AsyncAction__c action = AsyncActions.initAction(settings);
		Database.insert(action, System.AccessLevel.SYSTEM_MODE);

		Test.startTest();
		// Spin up a bunch of queueable jobs, until the limit is met
		AsyncActionLauncher.Factory factory = new AsyncActionLauncher.Factory(settings);
		for (Integer i = 0; i < Limits.getLimitQueueableJobs(); i++) {
			AsyncActionJob job = new AsyncActionJob(factory);
			System.enqueueJob(job);
		}
		// NOW try to launch the job
		Id jobId = new AsyncActionLauncher()?.launch(settings);
		Test.stopTest();

		Assert.isNull(jobId, 'A job was launched despite hitting queueable limits');
	}

	@IsTest
	static void shouldNotLaunchWithoutPendingActions() {
		AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		settings.Enabled__c = false;
		// No actions inserted!

		Test.startTest();
		Id jobId = new AsyncActionLauncher()?.launch(settings);
		Test.stopTest();

		Assert.isNull(jobId, 'A job was launched despite having no data');
	}

	@IsTest
	static void shouldNotLaunchDuplicateJob() {
		AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		AsyncAction__c action = AsyncActions.initAction(settings);
		Database.insert(action, System.AccessLevel.SYSTEM_MODE);

		Test.startTest();
		Id jobId1 = new AsyncActionLauncher()?.launch(settings);
		Id jobId2 = new AsyncActionLauncher()?.launch(settings);
		Test.stopTest();

		Assert.isNotNull(jobId1, 'Initial job was not launched');
		Assert.isNull(jobId2, 'Duplicate job was launched');
	}

	// **** HELPER **** //
	private static Integer getNumAsyncJobs() {
		return [
			SELECT COUNT()
			FROM AsyncApexJob
			WHERE ApexClass.Name = :AsyncActionJob.class.getName()
			WITH SYSTEM_MODE
		];
	}
}
