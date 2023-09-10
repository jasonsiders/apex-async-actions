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
        Id jobId = processor?.launch();
        Test.stopTest();

        Assert.isNotNull(jobId, 'The job was not launched');
		Map<Id, Account> accounts = new Map<Id, Account>([SELECT Id, (SELECT Id FROM Cases) FROM Account]);
		actions = [SELECT Id, Data__c, RelatedRecordId__c, Status__c FROM AsyncAction__c WHERE Id IN :actions];
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
		AsyncActionSetting__mdt settings = AsyncActionTestUtils.initGlobalSettings();
		AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(BadProcessor.class);
		config.Retries__c = 3;
		config.RetryInterval__c = 3;
		AsyncActionProcessor processor = new BadProcessor();
		List<AsyncAction__c> actions = AsyncActionProcessorTest.initTestActions(processor);
		insert actions;
		Id jobId;

		try {
			Test.startTest();
			jobId = processor?.launch(null);
			Test.stopTest();
		} catch (System.DmlException error) {
			// The BadProcessor will throw an error;
			// the finalizer will still run and handle the actions accordingly
		}

		Assert.isNotNull(jobId, 'The job was not launched');
		for (AsyncAction__c action : [
			SELECT Id, Data__c, Retries__c, RelatedRecordId__c, Scheduled__c, Status__c
			FROM AsyncAction__c
			WHERE Id IN :actions
		]) {
			Assert.areEqual(AsyncActionProcessor.Status.PENDING.name(), action?.Status__c, 'Action is no longer pending');
			Assert.areEqual(config?.Retries__c - 1, action?.Retries__c, 'Wrong Num Retries');
			DateTime now = DateTime.now();
			DateTime scheduled = action?.Scheduled__c;
			Assert.isTrue(scheduled > now, 'Scheduled Date is not in the future: ' + scheduled + '. Expected: ' + now);
		}
	}

    @IsTest
	static void shouldHandleFatalFailures() {
        AsyncActionProcessorTest.enableLogging(System.LoggingLevel.ERROR);
		AsyncActionSetting__mdt settings = AsyncActionTestUtils.initGlobalSettings();
		AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(BadProcessor.class);
		config.Retries__c = 0;
		AsyncActionProcessor processor = new BadProcessor();
		List<AsyncAction__c> actions = AsyncActionProcessorTest.initTestActions(processor);
		insert actions;
		Id jobId;

		try {
			Test.startTest();
			jobId = processor?.launch(null);
			Test.stopTest();
		} catch (System.DmlException error) {
			// The BadProcessor will throw an error;
			// the finalizer will still run and handle the actions accordingly
		}
        Test.getEventBus().deliver();

		Assert.isNotNull(jobId, 'The job was not launched');
		List<apxsp__Log__c> logs = [
			SELECT Id, apxsp__Related_Record_Id__c, apxsp__Message__c, apxsp__Source__c
			FROM apxsp__Log__c
			WHERE apxsp__Level__c = :System.LoggingLevel.ERROR.name()
		];
		Map<Id, List<apxsp__Log__c>> logsByRecordId = AsyncActionProcessorTest.mapLogsByRecordId(logs);
		actions = [SELECT Id, Data__c, RelatedRecordId__c, Status__c FROM AsyncAction__c WHERE Id IN :actions];
		for (AsyncAction__c action : actions) {
			Assert.areEqual(AsyncActionProcessor.Status.FAILED.name(), action?.Status__c, 'Action was not marked as failed');
			List<apxsp__Log__c> errorLogs = logsByRecordId?.get(action?.Id);
			Assert.areEqual(false, errorLogs?.isEmpty(), 'The error was not logged');
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
		Id jobId = processor?.launch(null);
		Test.stopTest();

		Assert.isNotNull(jobId, 'A job was not launched');
	}

	@IsTest 
	static void shouldNotLaunchJobIfQueueableLimitsExceeded() {
		AsyncActionSetting__mdt settings = AsyncActionTestUtils.initGlobalSettings();
		AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(MockProcessor.class);
		AsyncActionProcessor processor = new MockProcessor();
		List<AsyncAction__c> actions = AsyncActionProcessorTest.initTestActions(processor);
		insert actions;

		Test.startTest();
		// Spin up a bunch of queueable jobs, until the limit is met
		for (Integer i = 0; i < Limits.getLimitQueueableJobs(); i++) {
			System.enqueueJob(new GoodProcessor());
		}
		Id jobId = processor?.launch(null);
		Test.stopTest();

		Assert.isNull(jobId, 'A job was launched despite hitting queueable limits');
	}

	@IsTest 
	static void shouldNotLaunchJobIfDisabled() {
		AsyncActionSetting__mdt settings = AsyncActionTestUtils.initGlobalSettings();
		AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(MockProcessor.class);
		config.Enabled__c = false;
		AsyncActionProcessor processor = new MockProcessor();
		List<AsyncAction__c> actions = AsyncActionProcessorTest.initTestActions(processor);
		insert actions;
		
		Test.startTest();
		Id jobId = processor?.launch(null);
		Test.stopTest();

		Assert.isNull(jobId, 'A job was launched despite being disabled');
	}

	@IsTest 
	static void shouldNotLaunchJobIfNonePending() {
		AsyncActionSetting__mdt settings = AsyncActionTestUtils.initGlobalSettings();
		AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(MockProcessor.class);
		config.Enabled__c = false;
		AsyncActionProcessor processor = new MockProcessor();
		// No actions inserted!
		
		Test.startTest();
		Id jobId = processor?.launch(null);
		Test.stopTest();

		Assert.isNull(jobId, 'A job was launched despite having no data');
	}

	@IsTest 
	static void shouldNotLaunchJobIOneAlreadyExists() {
		AsyncActionSetting__mdt settings = AsyncActionTestUtils.initGlobalSettings();
		AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(MockProcessor.class);
		AsyncActionProcessor processor = new MockProcessor();
		List<AsyncAction__c> actions = AsyncActionProcessorTest.initTestActions(processor);
		insert actions;
		Id duplicateJobId = System.enqueueJob(processor); 

		Test.startTest();
		Id jobId = processor?.launch(null);
		Test.stopTest();

		Assert.isNull(jobId, 'A duplicate job was launched');
	}

	@IsTest 
	static void shouldIgnoreCurrentJobIdInDuplicateCheck() {
		// In practice, this should only ever be used from within an existing job
		AsyncActionSetting__mdt settings = AsyncActionTestUtils.initGlobalSettings();
		AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(MockProcessor.class);
		AsyncActionProcessor processor = new MockProcessor();
		List<AsyncAction__c> actions = AsyncActionProcessorTest.initTestActions(processor);
		insert actions;

		Test.startTest();
		Id originalJobId = System.enqueueJob(processor); 
		Id jobId = processor?.launch(originalJobId);
		Test.stopTest();

		Assert.isNotNull(jobId, 'A new job was not launched from the original job');
	}

	@IsTest 
	static void shouldRecurse() {
		// Note: In @IsTest context, recursion defaults to false
		// This prevents tests from running away on failure
		// In a real scenario, the job WOULD keep re-enqueueing on an error
		// Callers should mitigate this by using the fail() and reschedule() methods accordingly
		Integer baselineNumAccs = (Integer) [SELECT COUNT(Id) FROM Account][0]?.get('expr0');
		AsyncActionSetting__mdt settings = AsyncActionTestUtils.initGlobalSettings();
		AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(RecursiveProcessor.class);
		AsyncActionProcessor processor = new RecursiveProcessor();
		AsyncActionProcessor.allowRecursion = true; 
		AsyncAction__c action = processor?.initAction(null);
		insert action;
		
		Test.startTest();
		processor?.launch(null);
		Test.stopTest();

		// Each RecursiveProcessor action creates an account, and then re-enqueues up to 2 additional times
		// Since one action was inserted, 2 more will be inserted
		// A total of 3 actions, and 3 new accounts will be inserted
		Assert.areEqual(3, [SELECT Id FROM AsyncAction__c]?.size(), 'Wrong # of Actions');
		Assert.areEqual(baselineNumAccs + 3, [SELECT Id FROM Account]?.size(), 'Wrong # of Accounts');
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

    // **** INNER **** // 
    private class BadProcessor extends AsyncActionProcessor {
		public virtual override void process(List<AsyncAction__c> actions) {
			throw new System.DmlException('This is a test error');
		}

		public virtual override Type getType() {
			return BadProcessor.class;
		}
	}

	public class GoodProcessor extends AsyncActionProcessor {
		public override void process(List<AsyncAction__c> actions) {
			// Blindly complete each action
			for (AsyncAction__c action : actions) {
				action.Status__c = AsyncActionProcessor.Status.COMPLETED.name();
			}
			update actions;
		}

		public override Type getType() {
			return GoodProcessor.class;
		}
	}

	public class RecursiveProcessor extends AsyncActionProcessor {
		Integer numRecursions = 0;
		final Integer maxRecursions = 2; 

		public override void process(List<AsyncAction__c> actions) {
			// Create a random Account
			List<Account> accounts = new List<Account>();
			for (AsyncAction__c action : actions) {
				Account account = new Account(Name = 'Test Account #' + Crypto.getRandomInteger()); 
				accounts?.add(account); 
				action.Status__c = AsyncActionProcessor.Status.COMPLETED.name();
			}
			insert accounts; 
			update actions; 
			if (this.numRecursions < this.maxRecursions) {
				this.numRecursions = this.numRecursions + 1;
				AsyncAction__c action = this.initAction(null);
				insert action; 
			}
		}
		
		public override Type getType() {
			return RecursiveProcessor.class;
		}
	}
}