@SuppressWarnings('PMD.EmptyCatchBlock')
@IsTest
private class AsyncActionJobTest {
	private static final Integer TEST_SIZE = 200;

	// **** TESTS **** //
	@IsTest
	static void shouldProcessActions() {
		AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		AsyncActionLauncher.Factory factory = new AsyncActionLauncher.Factory(settings);
		AsyncActionJob job = new AsyncActionJob(factory);
		List<AsyncAction__c> actions = AsyncActionJobTest.initTestActions(settings);
		Database.insert(actions, System.AccessLevel.SYSTEM_MODE);

		Test.startTest();
		System.enqueueJob(job);
		Test.stopTest();

		for (AsyncAction__c action : AsyncActionJobTest.getUpdatedActions(actions)) {
			Assert.areEqual(AsyncActions.Status.COMPLETED.name(), action?.Status__c, 'Action was not completed');
		}
	}

	@IsTest
	static void shouldHandleFinalizerErrors() {
		// If an exception is thrown during the finalizer, the job will be aborted, but the actions will not be affected
		AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		settings.Retries__c = 0;
		AsyncActionLauncher.Factory factory = new AsyncActionLauncher.Factory(settings);
		AsyncActionJob job = new JobWithErrorInFinalizer(factory);
		List<AsyncAction__c> actions = AsyncActionJobTest.initTestActions(settings);
		Database.insert(actions, System.AccessLevel.SYSTEM_MODE);

		Test.startTest();
		Id jobId = System.enqueueJob(job);
		Test.stopTest();
		Test.getEventBus().deliver();

		List<AsyncApexJob> jobs = [
			SELECT Id, CronTriggerId
			FROM AsyncApexJob
			WHERE ApexClass.Name = :AsyncActionJob.class.getName() AND Id != :jobId
		];
		Assert.areEqual(true, jobs?.isEmpty(), 'Job was relaunched');
		for (AsyncAction__c action : AsyncActionJobTest.getUpdatedActions(actions)) {
			String expectedStatus = AsyncActions.Status.COMPLETED?.name();
			Assert.areEqual(expectedStatus, action?.Status__c, 'Action progress was overridden by Finalizer error');
		}
	}

	@IsTest
	static void shouldRecurse() {
		// Note: In @IsTest context, recursion defaults to false
		// This prevents tests from running away on failure
		// In a real scenario, the job WOULD keep re-enqueueing on an error
		// Callers should mitigate this by using the fail() and reschedule() methods accordingly
		AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		settings.Retries__c = 2;
		settings.RetryInterval__c = 0;
		AsyncActionLauncher.Factory factory = new AsyncActionLauncher.Factory(settings);
		AsyncActionJob job = new AsyncActionJob(factory);
		MockAsyncActionProcessor.pathType = MockAsyncActionProcessor.Path.JOB_ERROR;
		AsyncAction__c action = AsyncActions.initAction(settings);
		Database.insert(action, System.AccessLevel.SYSTEM_MODE);
		AsyncActionJob.allowRecursion = true;

		try {
			Test.startTest();
			System.enqueueJob(job);
			Test.stopTest();
		} catch (Exception error) {
			// Try/Catch needed to prevent aborting the test, and to trigger the finalizer
		}

		// Should keep re-enqueueing until the retries are exhausted
		List<AsyncApexJob> asyncJobs = [SELECT Id, Status FROM AsyncApexJob WHERE JobType = 'Queueable'];
		Assert.areEqual(settings?.Retries__c, asyncJobs?.size(), 'Wrong # of jobs');
		// Test.stopTest() will only process the first job -- unless aborted, they'll continue to run now, and throw an error
		for (AsyncApexJob asyncJob : asyncJobs) {
			if (asyncJob?.Status == 'Queued') {
				System.abortJob(asyncJob?.Id);
			}
		}
	}

	@IsTest
	static void shouldHandleFatalErrors() {
		// When the job enocunters an unexpected exception, the error will be logged & saved immediately via platform event
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		AsyncActionLauncher.Factory factory = new AsyncActionLauncher.Factory(settings);
		AsyncActionJob job = new AsyncActionJob(factory);
		MockAsyncActionProcessor.pathType = MockAsyncActionProcessor.Path.JOB_ERROR;
		List<AsyncAction__c> actions = AsyncActionJobTest.initTestActions(settings);
		Database.insert(actions, System.AccessLevel.SYSTEM_MODE);

		try {
			Test.startTest();
			System.enqueueJob(job);
			Test.stopTest();
			Test.getEventBus().deliver();
		} catch (Exception error) {
			// Try/Catch needed to prevent the test from aborting
		}

		for (AsyncAction__c action : AsyncActionJobTest.getUpdatedActions(actions)) {
			Assert.areNotEqual(null, action?.Error__c, 'Did not post error');
		}
	}

	// **** HELPER **** //
	static List<AsyncAction__c> getUpdatedActions(List<AsyncAction__c> originalActions) {
		return [
			SELECT Id, Error__c, Retries__c, NextEligibleAt__c, Status__c
			FROM AsyncAction__c
			WHERE Id IN :originalActions
		];
	}

	static List<AsyncAction__c> initTestActions(AsyncActionProcessor__mdt settings) {
		List<AsyncAction__c> actions = new List<AsyncAction__c>();
		for (Integer i = 0; i < TEST_SIZE; i++) {
			AsyncAction__c action = AsyncActions.initAction(settings);
			actions?.add(action);
		}
		return actions;
	}

	// **** INNER **** //
	private class JobWithErrorInFinalizer extends AsyncActionJob {
		public JobWithErrorInFinalizer(AsyncActionLauncher.Factory factory) {
			super(factory);
		}

		public override void finalize(System.FinalizerContext context) {
			throw new System.DmlException('This is a test exception');
		}
	}
}
