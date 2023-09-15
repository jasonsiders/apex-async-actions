@IsTest 
private class AsyncActionProcessorTest {
    @IsTest 
    static void shouldProcessActions() {
        AsyncActionSetting__mdt settings = AsyncActionTestUtils.initGlobalSettings();
        AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(MockProcessor.class);
        AsyncActionProcessor processor = new MockProcessor(); 
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
			Assert.areEqual(AsyncActionProcessor.Status.COMPLETED.name(), action?.Status__c, 'Action was not completed');
		}
    }

    @IsTest
	static void shouldTryAgainIfHasRetries() {
		AsyncActionProcessorTest.enableLogging(System.LoggingLevel.FINEST);
		AsyncActionSetting__mdt settings = AsyncActionTestUtils.initGlobalSettings();
		AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(MockProcessor.class);
		config.Retries__c = 3;
		config.RetryInterval__c = 3;
		MockProcessor processor = new MockProcessor();
		processor.pathType = MockProcessor.Path.JOB_ERROR;
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
		List<apxsp__Log__c> logs = AsyncActionProcessorTest.getErrorLogs();
		Assert.isFalse(logs?.isEmpty(), 'No errors were logged'); 
		Map<Id, List<apxsp__Log__c>> logsByRecordId = AsyncActionProcessorTest.mapLogsByRecordId(logs);
		for (AsyncAction__c action : AsyncActionProcessorTest.getUpdatedActions(actions)) {
			Assert.areEqual(AsyncActionProcessor.Status.PENDING.name(), action?.Status__c, 'Action is no longer pending');
			Assert.areEqual(config?.Retries__c - 1, action?.Retries__c, 'Wrong Num Retries');
			DateTime now = DateTime.now();
			DateTime scheduled = action?.Scheduled__c;
			Assert.isTrue(scheduled > now, 'Scheduled Date is not in the future: ' + scheduled + '. Expected: ' + now);
			List<apxsp__Log__c> errorLogs = logsByRecordId?.get(action?.Id);
			Assert.areEqual(false, errorLogs?.isEmpty(), 'No error logs related to action ' + action?.Id);
		}
	}

    @IsTest
	static void shouldNotTryAgainIfNoRetries() {
        AsyncActionProcessorTest.enableLogging(System.LoggingLevel.FINEST);
		AsyncActionSetting__mdt settings = AsyncActionTestUtils.initGlobalSettings();
		AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(MockProcessor.class);
		config.Retries__c = 0;
		MockProcessor processor = new MockProcessor();
		processor.pathType = MockProcessor.Path.JOB_ERROR; 
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
		List<apxsp__Log__c> logs = AsyncActionProcessorTest.getErrorLogs();
		Assert.isFalse(logs?.isEmpty(), 'No errors were logged'); 
		Map<Id, List<apxsp__Log__c>> logsByRecordId = AsyncActionProcessorTest.mapLogsByRecordId(logs);
		for (AsyncAction__c action : AsyncActionProcessorTest.getUpdatedActions(actions)) {
			Assert.areEqual(AsyncActionProcessor.Status.FAILED.name(), action?.Status__c, 'Action was not marked as failed');
			List<apxsp__Log__c> errorLogs = logsByRecordId?.get(action?.Id);
			Assert.areEqual(false, errorLogs?.isEmpty(), 'No error logs related to action ' + action?.Id);
		}
	}

	@IsTest 
	static void shouldKeepAliveIfErrors() {
		// If KEEP_ALIVE retry behavior is employed, an action will remain in "Pending", and its retries will not be decremented.
		AsyncActionProcessorTest.enableLogging(System.LoggingLevel.FINEST);
		AsyncActionSetting__mdt settings = AsyncActionTestUtils.initGlobalSettings();
		AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(MockProcessor.class);
		config.Retries__c = 3; 
		config.RetryInterval__c = 3;
		MockProcessor processor = new MockProcessor();
		processor.pathType = MockProcessor.Path.FAIL;
		processor.retryBehavior = AsyncActionProcessor.RetryBehavior.KEEP_ALIVE;
		List<AsyncAction__c> actions = AsyncActionProcessorTest.initTestActions(processor);
		insert actions;

		Test.startTest();
		Id jobId = System.enqueueJob(processor);
		Test.stopTest();
		Test.getEventBus().deliver();

		Assert.isNotNull(jobId, 'The job was not launched');
		List<apxsp__Log__c> logs = AsyncActionProcessorTest.getErrorLogs();
		Assert.isFalse(logs?.isEmpty(), 'No errors were logged'); 
		Map<Id, List<apxsp__Log__c>> logsByRecordId = AsyncActionProcessorTest.mapLogsByRecordId(logs);
		for (AsyncAction__c action : AsyncActionProcessorTest.getUpdatedActions(actions)) {
			Assert.areEqual(AsyncActionProcessor.Status.PENDING.name(), action?.Status__c, 'Action is not longer pending');
			Assert.areEqual(config?.Retries__c, action?.Retries__c, 'Retries was altered');
			Assert.isTrue(action?.Scheduled__c > DateTime.now(), 'Action was not rescheduled');
			List<apxsp__Log__c> errorLogs = logsByRecordId?.get(action?.Id);
			Assert.areEqual(false, errorLogs?.isEmpty(), 'No error logs related to action ' + action?.Id);
		}
	}

	@IsTest 
	static void shouldNotTryAgainIfSuddenDeath() {
		// If SUDDEN_DEATH retry behavior is employed, an action will be marked as "Failed", even if it has retries
		AsyncActionProcessorTest.enableLogging(System.LoggingLevel.FINEST);
		AsyncActionSetting__mdt settings = AsyncActionTestUtils.initGlobalSettings();
		AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(MockProcessor.class);
		config.Retries__c = 3;
		MockProcessor processor = new MockProcessor();
		processor.pathType = MockProcessor.Path.FAIL; 
		processor.retryBehavior = AsyncActionProcessor.RetryBehavior.SUDDEN_DEATH;
		List<AsyncAction__c> actions = AsyncActionProcessorTest.initTestActions(processor);
		insert actions;

		Test.startTest();
		Id jobId = System.enqueueJob(processor);
		Test.stopTest();
		Test.getEventBus().deliver();

		Assert.isNotNull(jobId, 'The job was not launched');
		List<apxsp__Log__c> logs = AsyncActionProcessorTest.getErrorLogs();
		Assert.isFalse(logs?.isEmpty(), 'No errors were logged'); 
		Map<Id, List<apxsp__Log__c>> logsByRecordId = AsyncActionProcessorTest.mapLogsByRecordId(logs);
		for (AsyncAction__c action : AsyncActionProcessorTest.getUpdatedActions(actions)) {
			Assert.areEqual(AsyncActionProcessor.Status.FAILED.name(), action?.Status__c, 'Action was not marked as failed');
			List<apxsp__Log__c> errorLogs = logsByRecordId?.get(action?.Id);
			Assert.areEqual(false, errorLogs?.isEmpty(), 'No error logs related to action ' + action?.Id);
		}
	}

	@IsTest 
	static void shouldHandleFinalizerErrors() {
		// If an exception is thrown during the finalizer, it should be caught and handled like an error during the queueable
		AsyncActionProcessorTest.enableLogging(System.LoggingLevel.FINEST);
		AsyncActionSetting__mdt settings = AsyncActionTestUtils.initGlobalSettings();
		AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(MockProcessor.class);
		config.Retries__c = 0;
		MockProcessor processor = new MockProcessor();
		processor.retryBehavior = AsyncActionProcessor.RetryBehavior.SUDDEN_DEATH;
		processor.pathType = MockProcessor.Path.FINALIZER_ERROR; 
		List<AsyncAction__c> actions = AsyncActionProcessorTest.initTestActions(processor);
		insert actions;

		Test.startTest();
		Id jobId = System.enqueueJob(processor);
		Test.stopTest();
		Test.getEventBus().deliver();

		Assert.isNotNull(jobId, 'The job was not launched');
		List<apxsp__Log__c> logs = AsyncActionProcessorTest.getErrorLogs();
		Assert.isFalse(logs?.isEmpty(), 'No errors were logged'); 
		Map<Id, List<apxsp__Log__c>> logsByRecordId = AsyncActionProcessorTest.mapLogsByRecordId(logs);
		for (AsyncAction__c action : AsyncActionProcessorTest.getUpdatedActions(actions)) {
			Assert.areEqual(AsyncActionProcessor.Status.FAILED.name(), action?.Status__c, 'Action was not marked as failed');
			List<apxsp__Log__c> errorLogs = logsByRecordId?.get(action?.Id);
			Assert.areEqual(false, errorLogs?.isEmpty(), 'No error logs related to action ' + action?.Id);
		}
	}

    @IsTest 
	static void shouldInitializeAnAction() {
		AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(MockProcessor.class);
		Id recordId = UserInfo.getUserId();

		Test.startTest();
		AsyncAction__c action = new MockProcessor()?.initAction(recordId);
		Test.stopTest();

		Assert.areEqual(config?.Retries__c, action?.Retries__c, 'Wrong # of retries');
		Assert.areEqual(MockProcessor.class?.getName(), action?.ProcessorClass__c, 'Unexpected Processor Class');
		Assert.areEqual(recordId, action?.RelatedRecordId__c, 'Unexpected Related Record Id');
		Assert.isNotNull(action?.Scheduled__c, 'Invalid Scheduled value');
		Assert.areEqual(AsyncActionProcessor.Status.PENDING.name(), action?.Status__c, 'Unexpected Status');
	}

    @IsTest
	static void shouldReturnProcessorType() {
		Type expected = MockProcessor.class;

		Test.startTest();
		Type actual = new MockProcessor().getType();
		Test.stopTest();

		Assert.areEqual(expected, actual, 'Wrong Type');
	}

    @IsTest 
	static void shouldLaunchJob() {
		AsyncActionSetting__mdt settings = AsyncActionTestUtils.initGlobalSettings();
		AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(MockProcessor.class);
		AsyncActionProcessor processor = new MockProcessor();
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
		AsyncActionProcessorTest.enableLogging(System.LoggingLevel.FINEST);
		AsyncActionSetting__mdt settings = AsyncActionTestUtils.initGlobalSettings();
		AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(MockProcessor.class);
		config.Retries__c = 2;
		config.RetryInterval__c = 0;
		MockProcessor processor = new MockProcessor();
		processor.pathType = MockProcessor.Path.JOB_ERROR; 
		AsyncAction__c action = processor?.initAction(null);
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
		List<AsyncApexJob> jobs = [SELECT Id FROM AsyncApexJob WHERE ApexClass.Name = 'MockProcessor'];
		Assert.areEqual(config?.Retries__c, jobs?.size(), 'Wrong # of jobs');
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

	static List<apxsp__Log__c> getErrorLogs() {
		return [
			SELECT Id, apxsp__Related_Record_Id__c
			FROM apxsp__Log__c
			WHERE apxsp__Level__c = :System.LoggingLevel.ERROR.name()
		];
	}

	static List<AsyncAction__c> getUpdatedActions(List<AsyncAction__c> originalActions) {
		return [
			SELECT Id, Data__c, Retries__c, RelatedRecordId__c, Scheduled__c, Status__c
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

    static Map<Id, List<apxsp__Log__c>> mapLogsByRecordId(List<apxsp__Log__c> logs) {
        Map<Id, List<apxsp__Log__c>> results = new Map<Id, List<apxsp__Log__c>>();
        for (apxsp__Log__c log : logs) {
            Id recordId = (Id) log?.apxsp__Related_Record_Id__c; 
            List<apxsp__Log__c> matching = results?.containsKey(recordId)
                ? results?.get(recordId)
                : new List<apxsp__Log__c>();
            matching?.add(log);
            results?.put(recordId, matching);
        }
        return results; 
    }

    static void enableLogging(System.LoggingLevel level) {
        insert new apxsp__Log_Setting__c(
            apxsp__Enabled__c = true, 
            apxsp__Level__c = level?.name(),
            SetupOwnerId = UserInfo.getUserId()
        );
    }
}