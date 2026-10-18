/**
 * @description Test class for AsyncActionJob functionality including processing, error handling, and recursion
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.EmptyCatchBlock')
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
		MockAsyncActionProcessor.pathType = MockAsyncActionProcessor.Path.SUCCESS;

		Test.startTest();
		System.enqueueJob(job);
		Test.stopTest();

		for (AsyncAction__c action : AsyncActionJobTest.getUpdatedActions(actions)) {
			Assert.areEqual(AsyncActions.Status.COMPLETED.name(), action?.Status__c, 'Action was not completed');
		}
	}

	@IsTest
	static void shouldProcessFailedActions() {
		AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		settings.Retries__c = 0;
		AsyncActionLauncher.Factory factory = new AsyncActionLauncher.Factory(settings);
		AsyncActionJob job = new AsyncActionJob(factory);
		List<AsyncAction__c> actions = AsyncActionJobTest.initTestActions(settings);
		Database.insert(actions, System.AccessLevel.SYSTEM_MODE);
		MockAsyncActionProcessor.pathType = MockAsyncActionProcessor.Path.FAIL;

		Test.startTest();
		System.enqueueJob(job);
		Test.stopTest();

		for (AsyncAction__c action : AsyncActionJobTest.getUpdatedActions(actions)) {
			Assert.areEqual(AsyncActions.Status.FAILED.name(), action?.Status__c, 'Action was not failed');
		}
	}

	@IsTest
	static void shouldHandleFatalErrors() {
		// When the job enocunters an unexpected exception, the error will be logged & saved immediately via platform event
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		AsyncActionLauncher.Factory factory = new AsyncActionLauncher.Factory(settings);
		AsyncActionJob job = new AsyncActionJob(factory);
		List<AsyncAction__c> actions = AsyncActionJobTest.initTestActions(settings);
		Database.insert(actions, System.AccessLevel.SYSTEM_MODE);
		MockAsyncActionProcessor.pathType = MockAsyncActionProcessor.Path.THROW_ERROR;

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
		MockAsyncActionProcessor.pathType = MockAsyncActionProcessor.Path.SUCCESS;

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
		AsyncAction__c action = AsyncActions.initAction(settings);
		Database.insert(action, System.AccessLevel.SYSTEM_MODE);
		AsyncActionJob.allowRecursion = true;
		MockAsyncActionProcessor.pathType = MockAsyncActionProcessor.Path.THROW_ERROR;

		try {
			Test.startTest();
			System.enqueueJob(job);
			Test.stopTest();
		} catch (Exception error) {
			// Try/Catch needed to prevent aborting the test, and to trigger the finalizer
		}

		// Should keep re-enqueueing until the retries are exhausted
		List<AsyncApexJob> asyncJobs = [
			SELECT Id, Status
			FROM AsyncApexJob
			WHERE ApexClass.Name = :AsyncActionJob.class.getName()
		];
		Assert.areEqual(settings?.Retries__c, asyncJobs?.size(), 'Wrong # of jobs');
		// Test.stopTest() will only process the first job -- unless aborted, they'll continue to run now, and throw an error
		for (AsyncApexJob asyncJob : asyncJobs) {
			if (asyncJob?.Status == 'Queued') {
				System.abortJob(asyncJob?.Id);
			}
		}
	}

	@IsTest
	static void shouldSkipActionsLockedByAnotherJob() {
		// When another job holds the actions past the lock wait, this job does nothing; the other job re-launches
		AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		AsyncActionLauncher.Factory factory = new AsyncActionLauncher.Factory(settings);
		AsyncActionJob job = new JobWithLockTimeout(factory);
		List<AsyncAction__c> actions = AsyncActionJobTest.initTestActions(settings);
		Database.insert(actions, System.AccessLevel.SYSTEM_MODE);
		AsyncActionJob.allowRecursion = true;
		// Fails the test if the processor is called with an empty batch
		MockAsyncActionProcessor.pathType = MockAsyncActionProcessor.Path.THROW_ERROR;

		Test.startTest();
		Id jobId = System.enqueueJob(job);
		Test.stopTest();

		List<AsyncApexJob> relaunchedJobs = [
			SELECT Id
			FROM AsyncApexJob
			WHERE ApexClass.Name = :AsyncActionJob.class.getName() AND Id != :jobId
		];
		Assert.areEqual(true, relaunchedJobs?.isEmpty(), 'Locked out job was relaunched');
		for (AsyncAction__c action : AsyncActionJobTest.getUpdatedActions(actions)) {
			String expectedStatus = AsyncActions.Status.PENDING?.name();
			Assert.areEqual(expectedStatus, action?.Status__c, 'Locked out job processed an action');
		}
	}

	@IsTest
	static void shouldNotFailActionsHandledByAnotherJob() {
		// After a job's work rolls back, a waiting job can process its actions before its finalizer runs
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		AsyncActionLauncher.Factory factory = new AsyncActionLauncher.Factory(settings);
		AsyncActionJob job = new AsyncActionJob(factory);
		List<AsyncAction__c> actions = AsyncActionJobTest.initTestActions(settings);
		for (AsyncAction__c action : actions) {
			action.Status__c = AsyncActions.Status.COMPLETED?.name();
		}
		Database.insert(actions, System.AccessLevel.SYSTEM_MODE);
		job.actionIds = new Map<Id, AsyncAction__c>(actions)?.keySet();
		FailedJobContext context = new FailedJobContext();

		Test.startTest();
		job.finalize(context);
		Test.stopTest();

		for (AsyncAction__c action : AsyncActionJobTest.getUpdatedActions(actions)) {
			Assert.isNull(action?.Error__c, 'Finalizer failed an action another job completed');
		}
	}

	@IsTest
	static void shouldProcessOldestActionsFirst() {
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		settings.BatchSize__c = 1;
		AsyncActionLauncher.Factory factory = new AsyncActionLauncher.Factory(settings);
		AsyncActionJob job = new AsyncActionJob(factory);
		// Insert the newer action first, so Id order and first-in-first-out order disagree
		AsyncAction__c newerAction = AsyncActions.initAction(settings);
		newerAction.NextEligibleAt__c = DateTime.now()?.addMinutes(-1);
		AsyncAction__c olderAction = AsyncActions.initAction(settings);
		olderAction.NextEligibleAt__c = DateTime.now()?.addMinutes(-2);
		List<AsyncAction__c> actions = new List<AsyncAction__c>{ newerAction, olderAction };
		Database.insert(actions, System.AccessLevel.SYSTEM_MODE);
		MockAsyncActionProcessor.pathType = MockAsyncActionProcessor.Path.SUCCESS;

		Test.startTest();
		System.enqueueJob(job);
		Test.stopTest();

		List<AsyncAction__c> updatedActions = AsyncActionJobTest.getUpdatedActions(actions);
		Map<Id, AsyncAction__c> updatedActionsById = new Map<Id, AsyncAction__c>(updatedActions);
		String olderStatus = updatedActionsById?.get(olderAction?.Id)?.Status__c;
		String newerStatus = updatedActionsById?.get(newerAction?.Id)?.Status__c;
		String completedStatus = AsyncActions.Status.COMPLETED?.name();
		String pendingStatus = AsyncActions.Status.PENDING?.name();
		Assert.areEqual(completedStatus, olderStatus, 'Oldest action was not processed');
		Assert.areEqual(pendingStatus, newerStatus, 'Newer action was processed first');
	}

	// **** HELPER **** //
	/**
	 * @description Helper method to retrieve updated AsyncAction__c records from database
	 * @param originalActions List of original AsyncAction__c records to query for updates
	 * @return List of updated AsyncAction__c records with current field values
	 */
	static List<AsyncAction__c> getUpdatedActions(List<AsyncAction__c> originalActions) {
		return [
			SELECT Id, Error__c, Retries__c, NextEligibleAt__c, Status__c
			FROM AsyncAction__c
			WHERE Id IN :originalActions
			WITH SYSTEM_MODE
		];
	}

	/**
	 * @description Helper method to create test AsyncAction__c records for testing
	 * @param settings The processor configuration to use when initializing actions
	 * @return List of initialized AsyncAction__c records for testing
	 */
	static List<AsyncAction__c> initTestActions(AsyncActionProcessor__mdt settings) {
		List<AsyncAction__c> actions = new List<AsyncAction__c>{};
		for (Integer i = 0; i < TEST_SIZE; i++) {
			AsyncAction__c action = AsyncActions.initAction(settings);
			actions?.add(action);
		}
		return actions;
	}

	// **** INNER **** //
	/**
	 * @description Test-specific AsyncActionJob subclass that throws an error in the finalizer
	 */
	private class JobWithErrorInFinalizer extends AsyncActionJob {
		/**
		 * @description Constructor for test job that will error in finalizer
		 * @param factory The factory to use for launching async actions
		 */
		public JobWithErrorInFinalizer(AsyncActionLauncher.Factory factory) {
			super(factory);
		}

		/**
		 * @description Overridden finalizer that throws a test exception
		 * @param context The finalizer context (unused in this test implementation)
		 */
		public override void finalize(System.FinalizerContext context) {
			throw new System.DmlException('This is a test exception');
		}
	}

	/** @description Test-specific AsyncActionJob subclass whose actions are locked by another job **/
	private class JobWithLockTimeout extends AsyncActionJob {
		/**
		 * @description Constructor for test job that can't lock its actions
		 * @param factory The factory to use for launching async actions
		 */
		public JobWithLockTimeout(AsyncActionLauncher.Factory factory) {
			super(factory);
		}

		/**
		 * @description Throws the exception the platform raises when a lock wait times out
		 * @param candidateIds Ids of the actions to lock (unused in this test implementation)
		 * @return Never returns
		 * @throws System.QueryException Always, as if another job held the lock
		 */
		public override List<AsyncAction__c> lockPendingActions(Set<Id> candidateIds) {
			throw new System.QueryException('Record Currently Unavailable');
		}
	}

	/** @description Finalizer context for a job that threw an unhandled exception **/
	private class FailedJobContext implements System.FinalizerContext {
		/**
		 * @description Returns the job Id (unused in these tests)
		 * @return null
		 */
		public Id getAsyncApexJobId() {
			return null;
		}

		/**
		 * @description Returns the exception the job threw
		 * @return A test exception
		 */
		public Exception getException() {
			return MockAsyncActionProcessor.error;
		}

		/**
		 * @description Returns the request Id (unused in these tests)
		 * @return null
		 */
		public String getRequestId() {
			return null;
		}

		/**
		 * @description Returns the job result
		 * @return UNHANDLED_EXCEPTION
		 */
		public System.ParentJobResult getResult() {
			return System.ParentJobResult.UNHANDLED_EXCEPTION;
		}
	}
}
