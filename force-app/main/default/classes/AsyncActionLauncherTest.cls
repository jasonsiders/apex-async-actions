@IsTest 
private class AsyncActionLauncherTest {
    @IsTest 
    static void shouldLaunchAllJobs() {
        Type processorType = MockProcessor.class;
        AsyncActionSetting__mdt settings = AsyncActionTestUtils.initGlobalSettings();
        AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(processorType);
        MockProcessor processor = new MockProcessor();
        AsyncAction__c action = processor?.initAction(null); 
        insert action; 

        Test.startTest();
        Map<Type, Id> results = AsyncActionLauncher.launchAll();
        Test.stopTest();
        
        Assert.isTrue(results?.containsKey(processorType), 'Did not attempt to launch ' + processorType);
        Assert.isNotNull(results?.get(processorType), 'Did not launch ' + processorType); 
    }

    @IsTest 
    static void shouldLaunchSpecifiedJobs() {
        Type processorType = MockProcessor.class;
        AsyncActionSetting__mdt settings = AsyncActionTestUtils.initGlobalSettings();
        AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(processorType);
        MockProcessor processor = new MockProcessor();
        AsyncAction__c action = processor?.initAction(null); 
        insert action;  

        Test.startTest();
        Map<Type, Id> results = AsyncActionLauncher.launchJobs(new List<AsyncActionProcessor__mdt>{config}, null);
        Test.stopTest();
        
        Assert.isTrue(results?.containsKey(processorType), 'Did not attempt to launch ' + processorType);
        Assert.isNotNull(results?.get(processorType), 'Did not launch ' + processorType); 
    }

    @IsTest 
    static void shouldNotLaunchInvalidJob() {
        Type fakeProcessorType = Account.class; // Obv not a real processor!
        AsyncActionSetting__mdt settings = AsyncActionTestUtils.initGlobalSettings();
        AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(fakeProcessorType); 
        insert new AsyncAction__c(
			ProcessorClass__c = String.valueOf(fakeProcessorType), 
			Scheduled__c = DateTime.now().addMinutes(-1),
			Status__c = 'Pending'
		);

        Test.startTest();
		Map<Type, Id> results = AsyncActionLauncher.launchAll();
		Test.stopTest();

        Assert.isNull(results?.get(fakeProcessorType), 'Launched a job for an invalid config');
    }

    @IsTest 
    static void shouldNotLaunchIfDisabled() {
        Type processorType = MockProcessor.class;
        AsyncActionSetting__mdt settings = AsyncActionTestUtils.initGlobalSettings();
        AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(processorType);
        config.Enabled__c = false;
        MockProcessor processor = new MockProcessor();
        AsyncAction__c action = processor?.initAction(null); 
        insert action;  

        Test.startTest();
        Map<Type, Id> results = AsyncActionLauncher.launchJobs(new List<AsyncActionProcessor__mdt>{config}, null);
        Test.stopTest();
        
        Assert.isNull(results?.get(processorType), 'Launched disabled job');
    }

    @IsTest 
    static void shouldNotLaunchIfAlreadyPending() {
        Type processorType = MockProcessor.class;
        AsyncActionSetting__mdt settings = AsyncActionTestUtils.initGlobalSettings();
        AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(processorType);
        MockProcessor processor = new MockProcessor();
        AsyncAction__c action = processor?.initAction(null); 
        insert action;  
        System.enqueueJob(processor);

        Test.startTest();
        Map<Type, Id> results = AsyncActionLauncher.launchJobs(new List<AsyncActionProcessor__mdt>{config}, null);
        Test.stopTest();
        
        Assert.isNull(results?.get(processorType), 'Launched job already in progress');
    }

    @IsTest 
    static void shouldIgnoreCurrentJobId() {
        Type processorType = MockProcessor.class;
        AsyncActionSetting__mdt settings = AsyncActionTestUtils.initGlobalSettings();
        AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(processorType);
        MockProcessor processor = new MockProcessor();
        AsyncAction__c action = processor?.initAction(null); 
        insert action;  
        Id currentJobId = System.enqueueJob(processor);

        Test.startTest();
        Map<Type, Id> results = AsyncActionLauncher.launchJobs(new List<AsyncActionProcessor__mdt>{config}, currentJobId);
        Test.stopTest();

        Assert.isTrue(results?.containsKey(processorType), 'Did not attempt to launch ' + processorType);
        Assert.isNotNull(results?.get(processorType), 'Did not launch ' + processorType); 
    }
    
    @IsTest 
    static void shouldCreateAValidProcessor() {
        AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(MockProcessor.class);

        Test.startTest();
        AsyncActionProcessor processor = AsyncActionLauncher.initProcessor(config);
        Test.stopTest();

        Assert.isNotNull(processor, 'Did not initialize a AsyncActionProcessor');
        Assert.isInstanceOfType(processor, MockProcessor.class, 'Wrong processor type generated');
    }

    @IsTest 
    static void shouldReturnNullIfInvalidProcessor() {
        AsyncActionProcessor__mdt config = new AsyncActionProcessor__mdt(ProcessorClass__c = null);

        Test.startTest();
        AsyncActionProcessor processor = AsyncActionLauncher.initProcessor(config);
        Test.stopTest();

        Assert.isNull(processor, 'Invalid processorName generated a AsyncActionProcessor anyways');
    }

    @IsTest 
	static void shouldNotLaunchJobIfQueueableLimitsExceeded() {
		AsyncActionSetting__mdt settings = AsyncActionTestUtils.initGlobalSettings();
		AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(MockProcessor.class);
		AsyncActionProcessor processor = new MockProcessor();
		insert processor?.initAction(null);
		// Spin up a bunch of queueable jobs, until the limit is met
		for (Integer i = 0; i < Limits.getLimitQueueableJobs(); i++) {
			System.enqueueJob(processor);
		}
		
		Test.startTest();
		Map<Type, Id> results = AsyncActionLauncher.launchJobs(config, null);
		Test.stopTest();

		Assert.isNull(results?.get(MockProcessor.class), 'A job was launched despite hitting queueable limits');
	} 

	@IsTest 
	static void shouldNotLaunchJobIfDisabled() {
		AsyncActionSetting__mdt settings = AsyncActionTestUtils.initGlobalSettings();
		AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(MockProcessor.class);
		config.Enabled__c = false;
		AsyncActionProcessor processor = new MockProcessor();
		insert processor?.initAction(null);
		
		Test.startTest();
		Map<Type, Id> results = AsyncActionLauncher.launchJobs(config, null);
		Test.stopTest();

		Assert.isNull(results?.get(MockProcessor.class), 'A job was launched despite being disabled');
	}

	@IsTest 
	static void shouldNotLaunchJobIfNonePending() {
		AsyncActionSetting__mdt settings = AsyncActionTestUtils.initGlobalSettings();
		AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(MockProcessor.class);
		config.Enabled__c = false;
		// No actions inserted!
		
		Test.startTest();
		Map<Type, Id> results = AsyncActionLauncher.launchJobs(config, null);
		Test.stopTest();

		Assert.isNull(results?.get(MockProcessor.class), 'A job was launched despite having no data');
	} 

	@IsTest 
	static void shouldNotLaunchJobIOneAlreadyExists() {
		AsyncActionSetting__mdt settings = AsyncActionTestUtils.initGlobalSettings();
		AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(MockProcessor.class);
		AsyncActionProcessor processor = new MockProcessor();
		insert processor?.initAction(null);
		Id duplicateJobId = System.enqueueJob(processor); 

		Test.startTest();
		Map<Type, Id> results = AsyncActionLauncher.launchJobs(config, null);
		Test.stopTest();

		Assert.isNull(results?.get(MockProcessor.class), 'A duplicate job was launched');
	} 

	@IsTest 
	static void shouldIgnoreCurrentJobIdInDuplicateCheck() {
		// In practice, this should only ever be used from within an existing job
		AsyncActionSetting__mdt settings = AsyncActionTestUtils.initGlobalSettings();
		AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(MockProcessor.class);
		AsyncActionProcessor processor = new MockProcessor();
		insert processor?.initAction(null);
		Id originalJobId = System.enqueueJob(processor); 

		Test.startTest();
		Map<Type, Id> results = AsyncActionLauncher.launchJobs(config, originalJobId);
		Test.stopTest();

		Assert.isNotNull(results?.get(MockProcessor.class), 'A new job was not launched from the original job');
	}
}