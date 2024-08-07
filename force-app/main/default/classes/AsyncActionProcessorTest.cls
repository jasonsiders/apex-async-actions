@IsTest
private class AsyncActionProcessorTest {
	@IsTest
	static void shouldProcessActions() {
		AsyncActionScheduledJob__mdt jobSettings = AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(MockAsyncActionProcessor.class);
		AsyncActionProcessor processor = new MockAsyncActionProcessor();
		List<AsyncAction__c> actions = AsyncActionProcessorTest.initTestActions(processor);
		insert actions;

		Test.startTest();
		Id jobId = System.enqueueJob(processor);
		Test.stopTest();

		Assert.isNotNull(jobId, 'The job was not launched');
		Map<Id, Account> accounts = new Map<Id, Account>([SELECT Id, (SELECT Id FROM Cases) FROM Account]);
		actions = AsyncActionProcessorTest.getUpdatedActions(actions);
		Assert.areEqual(accounts?.size(), actions?.size(), 'Wrong # of actions created');
		for (AsyncAction__c action : actions) {
			Id recordId = action?.RelatedRecordId__c;
			Account account = accounts?.get(recordId);
			Map<String, Object> params = (Map<String, Object>) JSON.deserializeUntyped(action?.Data__c);
			Integer numCases = (Integer) params?.get('numCases');
			Assert.areEqual(numCases, account?.Cases?.size(), 'Wrong # of Cases created');
			Assert.areEqual(
				AsyncActionProcessor.Status.COMPLETED.name(),
				action?.Status__c,
				'Action was not completed'
			);
			Assert.isNotNull(action?.LastRun__c, 'Missing Last Run');
		}
	}

	@IsTest
	static void shouldTryAgainIfHasRetries() {
		AsyncActionScheduledJob__mdt jobSettings = AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(MockAsyncActionProcessor.class);
		config.Retries__c = 3;
		config.RetryInterval__c = 3;
		MockAsyncActionProcessor processor = new MockAsyncActionProcessor();
		processor.pathType = MockAsyncActionProcessor.Path.JOB_ERROR;
		List<AsyncAction__c> actions = AsyncActionProcessorTest.initTestActions(processor);
		insert actions;
		Id jobId;

		try {
			Test.startTest();
			jobId = System.enqueueJob(processor);
			Test.stopTest();
		} catch (System.DmlException error) {
			// Try/Catch needed to prevent the test from aborting
		}
		Test.getEventBus().deliver();

		Assert.isNotNull(jobId, 'The job was not launched');
		for (AsyncAction__c action : AsyncActionProcessorTest.getUpdatedActions(actions)) {
			Assert.areEqual(
				AsyncActionProcessor.Status.PENDING.name(),
				action?.Status__c,
				'Action is no longer pending'
			);
			Assert.areEqual(config?.Retries__c - 1, action?.Retries__c, 'Wrong Num Retries');
			DateTime now = DateTime.now();
			DateTime scheduled = action?.Scheduled__c;
			Assert.isTrue(scheduled > now, 'Scheduled Date is not in the future: ' + scheduled + '. Expected: ' + now);
		}
	}

	@IsTest
	static void shouldNotTryAgainIfNoRetries() {
		AsyncActionScheduledJob__mdt jobSettings = AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(MockAsyncActionProcessor.class);
		config.Retries__c = 0;
		MockAsyncActionProcessor processor = new MockAsyncActionProcessor();
		processor.pathType = MockAsyncActionProcessor.Path.JOB_ERROR;
		List<AsyncAction__c> actions = AsyncActionProcessorTest.initTestActions(processor);
		insert actions;
		Id jobId;

		try {
			Test.startTest();
			jobId = System.enqueueJob(processor);
			Test.stopTest();
		} catch (System.DmlException error) {
			// Try/Catch needed to prevent the test from aborting
		}
		Test.getEventBus().deliver();

		Assert.isNotNull(jobId, 'The job was not launched');
		for (AsyncAction__c action : AsyncActionProcessorTest.getUpdatedActions(actions)) {
			Assert.areEqual(
				AsyncActionProcessor.Status.FAILED.name(),
				action?.Status__c,
				'Action was not marked as failed'
			);
			Assert.isNotNull(action?.Error__c, 'Missing Error details');
		}
	}

	@IsTest
	static void shouldKeepAliveIfErrors() {
		// If KEEP_ALIVE retry behavior is employed, an action will remain in "Pending", and its retries will not be decremented.
		AsyncActionScheduledJob__mdt jobSettings = AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(MockAsyncActionProcessor.class);
		config.Retries__c = 3;
		config.RetryInterval__c = 3;
		MockAsyncActionProcessor processor = new MockAsyncActionProcessor();
		processor.pathType = MockAsyncActionProcessor.Path.FAIL;
		processor.retryBehavior = AsyncActionProcessor.RetryBehavior.KEEP_ALIVE;
		List<AsyncAction__c> actions = AsyncActionProcessorTest.initTestActions(processor);
		insert actions;

		Test.startTest();
		Id jobId = System.enqueueJob(processor);
		Test.stopTest();
		Test.getEventBus().deliver();

		Assert.isNotNull(jobId, 'The job was not launched');
		for (AsyncAction__c action : AsyncActionProcessorTest.getUpdatedActions(actions)) {
			Assert.areEqual(
				AsyncActionProcessor.Status.PENDING.name(),
				action?.Status__c,
				'Action is not longer pending'
			);
			Assert.isNotNull(action?.LastRun__c, 'Missing Last Run');
			Assert.areEqual(config?.Retries__c, action?.Retries__c, 'Retries was altered');
			Assert.isTrue(action?.Scheduled__c > DateTime.now(), 'Action was not rescheduled');
		}
	}

	@IsTest
	static void shouldNotTryAgainIfSuddenDeath() {
		// If SUDDEN_DEATH retry behavior is employed, an action will be marked as "Failed", even if it has retries
		AsyncActionScheduledJob__mdt jobSettings = AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(MockAsyncActionProcessor.class);
		config.Retries__c = 3;
		MockAsyncActionProcessor processor = new MockAsyncActionProcessor();
		processor.pathType = MockAsyncActionProcessor.Path.FAIL;
		processor.retryBehavior = AsyncActionProcessor.RetryBehavior.SUDDEN_DEATH;
		List<AsyncAction__c> actions = AsyncActionProcessorTest.initTestActions(processor);
		insert actions;

		Test.startTest();
		Id jobId = System.enqueueJob(processor);
		Test.stopTest();
		Test.getEventBus().deliver();

		Assert.isNotNull(jobId, 'The job was not launched');
		for (AsyncAction__c action : AsyncActionProcessorTest.getUpdatedActions(actions)) {
			Assert.areEqual(
				AsyncActionProcessor.Status.FAILED.name(),
				action?.Status__c,
				'Action was not marked as failed'
			);
			Assert.isNotNull(action?.LastRun__c, 'Missing Last Run');
			Assert.isNotNull(action?.Error__c, 'Missing Error details');
		}
	}

	@IsTest
	static void shouldHandleFinalizerErrors() {
		// If an exception is thrown during the finalizer, the job will be aborted, but the actions will not be affected
		AsyncActionScheduledJob__mdt jobSettings = AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(MockAsyncActionProcessor.class);
		config.Retries__c = 0;
		MockAsyncActionProcessor processor = new MockAsyncActionProcessor();
		processor.pathType = MockAsyncActionProcessor.Path.FINALIZER_ERROR;
		List<AsyncAction__c> actions = AsyncActionProcessorTest.initTestActions(processor);
		insert actions;

		Test.startTest();
		Id jobId = System.enqueueJob(processor);
		Test.stopTest();
		Test.getEventBus().deliver();

		List<AsyncApexJob> jobs = [
			SELECT Id, CronTriggerId
			FROM AsyncApexJob
			WHERE ApexClass.Name = 'MockAsyncActionProcessor' AND Id != :jobId
		];
		Assert.areEqual(true, jobs?.isEmpty(), 'Job was relaunched');
		for (AsyncAction__c action : AsyncActionProcessorTest.getUpdatedActions(actions)) {
			String expectedStatus = AsyncActionProcessor.Status.COMPLETED?.name();
			Assert.areEqual(expectedStatus, action?.Status__c, 'Action progress was overridden by Finalizer error');
		}
	}

	@IsTest
	static void shouldInitializeAnAction() {
		AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(MockAsyncActionProcessor.class);
		Id recordId = UserInfo.getUserId();

		Test.startTest();
		AsyncAction__c action = new MockAsyncActionProcessor()?.initAction(recordId);
		Test.stopTest();

		Assert.areEqual(config?.Retries__c, action?.Retries__c, 'Wrong # of retries');
		Assert.areEqual(
			MockAsyncActionProcessor.class?.getName(),
			action?.ProcessorClass__c,
			'Unexpected Processor Class'
		);
		Assert.areEqual(recordId, action?.RelatedRecordId__c, 'Unexpected Related Record Id');
		Assert.isNotNull(action?.Scheduled__c, 'Invalid Scheduled value');
		Assert.areEqual(AsyncActionProcessor.Status.PENDING.name(), action?.Status__c, 'Unexpected Status');
	}

	@IsTest
	static void shouldInitializeActionsFromSObjects() {
		MockAsyncActionProcessor processor = new MockAsyncActionProcessor();
		User user = new User(Id = UserInfo.getUserId());
		String data = '{}';

		// Should work w/SObjects & data
		AsyncAction__c action1 = processor?.initAction(user, data);
		Assert.areEqual(user?.Id, action1?.RelatedRecordId__c, 'Wrong Related Record Id');
		Assert.areEqual(data, action1?.Data__c, 'Wrong Data');

		// Should work w/SObjects only
		AsyncAction__c action2 = processor?.initAction(user);
		Assert.areEqual(user?.Id, action2?.RelatedRecordId__c, 'Wrong Related Record Id');
		Assert.areEqual(null, action2?.Data__c, 'Wrong Data');
	}

	@IsTest
	static void shouldReturnProcessorType() {
		Type expected = MockAsyncActionProcessor.class;

		Test.startTest();
		Type actual = new MockAsyncActionProcessor().getType();
		Test.stopTest();

		Assert.areEqual(expected, actual, 'Wrong Type');
	}

	@IsTest
	static void shouldLaunchJob() {
		AsyncActionScheduledJob__mdt jobSettings = AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(MockAsyncActionProcessor.class);
		AsyncActionProcessor processor = new MockAsyncActionProcessor();
		List<AsyncAction__c> actions = AsyncActionProcessorTest.initTestActions(processor);
		insert actions;

		Test.startTest();
		Id jobId = System.enqueueJob(processor);
		Test.stopTest();

		Assert.isNotNull(jobId, 'A job was not launched');
	}

	@IsTest
	static void shouldRecurse() {
		// Note: In @IsTest context, recursion defaults to false
		// This prevents tests from running away on failure
		// In a real scenario, the job WOULD keep re-enqueueing on an error
		// Callers should mitigate this by using the fail() and reschedule() methods accordingly
		AsyncActionScheduledJob__mdt jobSettings = AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(MockAsyncActionProcessor.class);
		config.Retries__c = 2;
		config.RetryInterval__c = 0;
		MockAsyncActionProcessor processor = new MockAsyncActionProcessor();
		processor.pathType = MockAsyncActionProcessor.Path.JOB_ERROR;
		AsyncAction__c action = processor?.initAction();
		insert action;
		AsyncActionTestUtils.setAllowRecursion(true);

		try {
			Test.startTest();
			System.enqueueJob(processor);
			Test.stopTest();
		} catch (Exception error) {
			// Try/Catch needed to prevent aborting the test, and to trigger the finalizer
		}

		// Should keep re-enqueueing until the retries are exhausted
		List<AsyncApexJob> jobs = [SELECT Id FROM AsyncApexJob WHERE ApexClass.Name = 'MockAsyncActionProcessor'];
		Assert.areEqual(config?.Retries__c, jobs?.size(), 'Wrong # of jobs');
	}

	@IsTest
	static void shouldHandleFatalErrors() {
		// When the job enocunters an unexpected exception, the error will be logged & saved immediately via platform event
		AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(MockAsyncActionProcessor.class);
		MockAsyncActionProcessor processor = new MockAsyncActionProcessor();
		processor.pathType = MockAsyncActionProcessor.Path.JOB_ERROR;
		List<AsyncAction__c> actions = AsyncActionProcessorTest.initTestActions(processor);
		insert actions;

		try {
			Test.startTest();
			Id jobId = System.enqueueJob(processor);
			Test.stopTest();
		} catch (Exception error) {
			// Try/Catch needed to prevent the test from aborting
		}
		Test.getEventBus().deliver();

		for (AsyncAction__c action : AsyncActionProcessorTest.getUpdatedActions(actions)) {
			Assert.areNotEqual(null, action?.Error__c, 'Did not post error');
		}
	}

	@IsTest
	static void shouldBypassFinalizerReenqueueLimits() {
		// Finalizers can re-enqueue failed jobs a limit of 5 times.
		// Re-enqueueing a failed job for the 6th time will produce a System.AsyncException
		// The AsyncActionProcessor should catch this error and launch again, this time via platform event
		AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(MockAsyncActionProcessor.class);
		config.BypassFinalizerRetryLimit__c = true;
		MockAsyncActionProcessor processor = new MockAsyncActionProcessor();
		processor.error = new System.AsyncException();
		processor.pathType = MockAsyncActionProcessor.Path.FINALIZER_ERROR;
		AsyncAction__c action = processor?.initAction();
		insert action;
		AsyncActionTestUtils.setAllowRecursion(true);

		// Because of @IsTest stack depth issues, we can't actuallly test the the 5x behavior,
		// but we can check that a job was still enqueued by calling the finzlier directly
		System.FinalizerContext context;
		processor?.execute(context);
		Test.getEventBus().deliver();

		List<AsyncApexJob> jobs = [SELECT Id FROM AsyncApexJob WHERE ApexClass.Name = 'MockAsyncActionProcessor'];
		Assert.areEqual(false, jobs?.isEmpty(), 'Job was not relaunched');
	}

	@IsTest
	static void shouldRespectFinalizerReenqueueLimits() {
		// Finalizers can re-enqueue failed jobs a limit of 5 times.
		// Re-enqueueing a failed job for the 6th time will produce a System.AsyncException
		// The AsyncActionProcessor should catch this error and launch again, this time via platform event
		AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(MockAsyncActionProcessor.class);
		config.BypassFinalizerRetryLimit__c = false;
		MockAsyncActionProcessor processor = new MockAsyncActionProcessor();
		processor.error = new System.AsyncException();
		processor.pathType = MockAsyncActionProcessor.Path.FINALIZER_ERROR;
		AsyncAction__c action = processor?.initAction();
		insert action;
		AsyncActionTestUtils.setAllowRecursion(true);

		// Because of @IsTest stack depth issues, we can't actuallly test the the 5x behavior,
		// but we can check that a job was still enqueued by calling the finzlier directly
		System.FinalizerContext context;
		processor?.execute(context);
		Test.getEventBus().deliver();

		List<AsyncApexJob> jobs = [SELECT Id FROM AsyncApexJob WHERE ApexClass.Name = 'MockAsyncActionProcessor'];
		Assert.areEqual(true, jobs?.isEmpty(), 'Job was relaunched');
	}

	// **** HELPER **** //
	@TestSetup
	static void setup() {
		List<Account> accounts = new List<Account>();
		for (Integer i = 0; i < 100; i++) {
			Account account = new Account(Name = 'Test Account #' + i);
			accounts.add(account);
		}
		insert accounts;
	}

	static List<AsyncAction__c> getUpdatedActions(List<AsyncAction__c> originalActions) {
		return [
			SELECT Id, Data__c, Error__c, LastRun__c, Retries__c, RelatedRecordId__c, Scheduled__c, Status__c
			FROM AsyncAction__c
			WHERE Id IN :originalActions
		];
	}

	static List<AsyncAction__c> initTestActions(AsyncActionProcessor processor) {
		List<AsyncAction__c> actions = new List<AsyncAction__c>();
		for (Account account : [SELECT Id FROM Account]) {
			Integer numCases = Integer.valueOf(Math.random() * 3);
			Map<String, Object> params = new Map<String, Object>{ 'numCases' => numCases };
			AsyncAction__c action = processor?.initAction(account?.Id);
			action.Data__c = JSON.serialize(params);
			actions?.add(action);
		}
		return actions;
	}
}
