@SuppressWarnings('PMD.EmptyCatchBlock')
@IsTest
private class AsyncActionJobTest {
	private static final Integer TEST_SIZE = 100;

	// **** TESTS **** //
	@IsTest
	static void shouldProcessActions() {
		AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		AsyncActionJob job = new AsyncActionJob(settings);
		List<AsyncAction__c> actions = AsyncActionJobTest.initTestActions(settings);
		insert actions;

		Test.startTest();
		Id jobId = System.enqueueJob(job);
		Test.stopTest();

		Assert.isNotNull(jobId, 'The job was not launched');
		Map<Id, Account> accounts = new Map<Id, Account>([SELECT Id, (SELECT Id FROM Cases) FROM Account]);
		actions = AsyncActionJobTest.getUpdatedActions(actions);
		Assert.areEqual(accounts?.size(), actions?.size(), 'Wrong # of actions created');
		for (AsyncAction__c action : actions) {
			Id recordId = action?.RelatedRecordId__c;
			Account account = accounts?.get(recordId);
			Map<String, Object> params = (Map<String, Object>) JSON.deserializeUntyped(action?.Data__c);
			Integer numCases = (Integer) params?.get('numCases');
			Assert.areEqual(numCases, account?.Cases?.size(), 'Wrong # of Cases created');
			Assert.areEqual(AsyncActions.Status.COMPLETED.name(), action?.Status__c, 'Action was not completed');
		}
	}

	@IsTest
	static void shouldTryAgainIfHasRetries() {
		AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		settings.Retries__c = 3;
		settings.RetryInterval__c = 3;
		AsyncActionJob job = new AsyncActionJob(settings);
		MockAsyncActionProcessor.pathType = MockAsyncActionProcessor.Path.JOB_ERROR;
		List<AsyncAction__c> actions = AsyncActionJobTest.initTestActions(settings);
		insert actions;
		Id jobId;

		try {
			Test.startTest();
			jobId = System.enqueueJob(job);
			Test.stopTest();
		} catch (System.DmlException error) {
			// Try/Catch needed to prevent the test from aborting
		}
		Test.getEventBus().deliver();

		Assert.isNotNull(jobId, 'The job was not launched');
		for (AsyncAction__c action : AsyncActionJobTest.getUpdatedActions(actions)) {
			Assert.areEqual(AsyncActions.Status.PENDING.name(), action?.Status__c, 'Action is no longer pending');
			Assert.areEqual(settings?.Retries__c - 1, action?.Retries__c, 'Wrong Num Retries');
			DateTime now = DateTime.now();
			DateTime nextEligibleAt = action?.NextEligibleAt__c;
			Assert.isTrue(
				nextEligibleAt > now,
				'Next Eligible At is not in the future: ' + nextEligibleAt + '. Expected: ' + now
			);
		}
	}

	@IsTest
	static void shouldNotTryAgainIfNoRetries() {
		AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		settings.Retries__c = 0;
		AsyncActionJob job = new AsyncActionJob(settings);
		MockAsyncActionProcessor.pathType = MockAsyncActionProcessor.Path.JOB_ERROR;
		List<AsyncAction__c> actions = AsyncActionJobTest.initTestActions(settings);
		insert actions;
		Id jobId;

		try {
			Test.startTest();
			jobId = System.enqueueJob(job);
			Test.stopTest();
		} catch (System.DmlException error) {
			// Try/Catch needed to prevent the test from aborting
		}
		Test.getEventBus().deliver();

		Assert.isNotNull(jobId, 'The job was not launched');
		for (AsyncAction__c action : AsyncActionJobTest.getUpdatedActions(actions)) {
			Assert.areEqual(AsyncActions.Status.FAILED.name(), action?.Status__c, 'Action was not marked as failed');
			Assert.isNotNull(action?.Error__c, 'Missing Error details');
		}
	}

	@IsTest
	static void shouldKeepAliveIfErrors() {
		// If KEEP_ALIVE retry behavior is employed, an action will remain in "Pending", and its retries will not be decremented.
		AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		settings.Retries__c = 3;
		settings.RetryInterval__c = 3;
		AsyncActionJob job = new AsyncActionJob(settings);
		MockAsyncActionProcessor.pathType = MockAsyncActionProcessor.Path.FAIL;
		MockAsyncActionProcessor.retryBehavior = AsyncActionErrorHandler.RetryBehavior.KEEP_ALIVE;
		List<AsyncAction__c> actions = AsyncActionJobTest.initTestActions(settings);
		insert actions;

		Test.startTest();
		Id jobId = System.enqueueJob(job);
		Test.stopTest();
		Test.getEventBus().deliver();

		Assert.isNotNull(jobId, 'The job was not launched');
		for (AsyncAction__c action : AsyncActionJobTest.getUpdatedActions(actions)) {
			Assert.areEqual(AsyncActions.Status.PENDING.name(), action?.Status__c, 'Action is not longer pending');
			Assert.areEqual(settings?.Retries__c, action?.Retries__c, 'Retries was altered');
			Assert.isTrue(action?.NextEligibleAt__c > DateTime.now(), 'Action was not rescheduled');
		}
	}

	@IsTest
	static void shouldNotTryAgainIfSuddenDeath() {
		// If SUDDEN_DEATH retry behavior is employed, an action will be marked as "Failed", even if it has retries
		AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		settings.Retries__c = 3;
		AsyncActionJob job = new AsyncActionJob(settings);
		MockAsyncActionProcessor.pathType = MockAsyncActionProcessor.Path.FAIL;
		MockAsyncActionProcessor.retryBehavior = AsyncActionErrorHandler.RetryBehavior.SUDDEN_DEATH;
		List<AsyncAction__c> actions = AsyncActionJobTest.initTestActions(settings);
		insert actions;

		Test.startTest();
		Id jobId = System.enqueueJob(job);
		Test.stopTest();
		Test.getEventBus().deliver();

		Assert.isNotNull(jobId, 'The job was not launched');
		for (AsyncAction__c action : AsyncActionJobTest.getUpdatedActions(actions)) {
			Assert.areEqual(AsyncActions.Status.FAILED.name(), action?.Status__c, 'Action was not marked as failed');
			Assert.isNotNull(action?.Error__c, 'Missing Error details');
		}
	}

	@IsTest
	static void shouldHandleFinalizerErrors() {
		// If an exception is thrown during the finalizer, the job will be aborted, but the actions will not be affected
		AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		settings.Retries__c = 0;
		AsyncActionJob job = new JobWithErrorInFinalizer(settings);
		List<AsyncAction__c> actions = AsyncActionJobTest.initTestActions(settings);
		insert actions;

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
	static void shouldLaunchJob() {
		AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		AsyncActionJob job = new AsyncActionJob(settings);
		List<AsyncAction__c> actions = AsyncActionJobTest.initTestActions(settings);
		insert actions;

		Test.startTest();
		Id jobId = System.enqueueJob(job);
		Test.stopTest();

		Assert.isNotNull(jobId, 'A job was not launched');
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
		AsyncActionJob job = new AsyncActionJob(settings);
		MockAsyncActionProcessor.pathType = MockAsyncActionProcessor.Path.JOB_ERROR;
		AsyncAction__c action = AsyncActions.initAction(settings);
		insert action;
		AsyncActionTestUtils.setAllowRecursion(true);

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
		AsyncActionJob job = new AsyncActionJob(settings);
		MockAsyncActionProcessor.pathType = MockAsyncActionProcessor.Path.JOB_ERROR;
		List<AsyncAction__c> actions = AsyncActionJobTest.initTestActions(settings);
		insert actions;

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
	@TestSetup
	static void setup() {
		List<Account> accounts = new List<Account>();
		for (Integer i = 0; i < TEST_SIZE; i++) {
			Account account = new Account(Name = 'Test Account #' + i);
			accounts.add(account);
		}
		insert accounts;
	}

	static List<AsyncAction__c> getUpdatedActions(List<AsyncAction__c> originalActions) {
		return [
			SELECT Id, Data__c, Error__c, Retries__c, RelatedRecordId__c, NextEligibleAt__c, Status__c
			FROM AsyncAction__c
			WHERE Id IN :originalActions
		];
	}

	static List<AsyncAction__c> initTestActions(AsyncActionProcessor__mdt settings) {
		List<AsyncAction__c> actions = new List<AsyncAction__c>();
		for (Account account : [SELECT Id FROM Account LIMIT :TEST_SIZE]) {
			Integer numCases = Integer.valueOf(Math.random() * 3);
			Map<String, Object> params = new Map<String, Object>{ 'numCases' => numCases };
			AsyncAction__c action = AsyncActions.initAction(settings, account?.Id);
			action.Data__c = JSON.serialize(params);
			actions?.add(action);
		}
		return actions;
	}

	// **** INNER **** //
	private class JobWithErrorInFinalizer extends AsyncActionJob {
		public JobWithErrorInFinalizer(AsyncActionProcessor__mdt settings) {
			super(settings);
		}

		public override void finalize(System.FinalizerContext context) {
			System.debug('@jason: in child finalizer');
			throw new System.DmlException('This is a test exception');
		}
	}
}
