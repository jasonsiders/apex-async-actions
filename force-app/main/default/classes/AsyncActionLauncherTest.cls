@IsTest
private class AsyncActionLauncherTest {
	@IsTest
	static void shouldCreateAValidApexProcessor() {
		AsyncActionProcessor__mdt config = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);

		Test.startTest();
		AsyncActionProcessor processor = new AsyncActionLauncher()?.initProcessor(config);
		Test.stopTest();

		Assert.isNotNull(processor, 'Did not initialize a AsyncActionProcessor');
		Assert.isInstanceOfType(processor, MockAsyncActionProcessor.class, 'Wrong processor type generated');
	}

	@IsTest
	static void shouldCreateAValidFlowProcessor() {
		AsyncActionProcessor__mdt config = AsyncActionTestUtils.initFlowProcessor('My_Test_Flow');

		Test.startTest();
		AsyncActionProcessor processor = new AsyncActionLauncher()?.initProcessor(config);
		Test.stopTest();

		Assert.isNotNull(processor, 'Did not initialize a AsyncActionProcessor');
		Assert.isInstanceOfType(processor, AsyncActionFlowProcessor.class, 'Wrong processor type generated');
	}

	@IsTest
	static void shouldReturnNullIfInvalidProcessor() {
		AsyncActionProcessor__mdt config = AsyncActionTestUtils.initApexProcessor(null);

		Test.startTest();
		AsyncActionProcessor processor = new AsyncActionLauncher()?.initProcessor(config);
		Test.stopTest();

		Assert.isNull(processor, 'Invalid processorName generated a AsyncActionProcessor anyways');
	}

	@IsTest
	static void shouldLaunchAllJobs() {
		Type processorType = MockAsyncActionProcessor.class;
		AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionTestUtils.initApexProcessor(processorType);
		MockAsyncActionProcessor processor = new MockAsyncActionProcessor();
		AsyncAction__c action = processor?.initAction();
		insert action;

		Test.startTest();
		new AsyncActionLauncher()?.launchAll();
		Test.stopTest();

		Map<String, List<AsyncApexJob>> results = AsyncActionLauncherTest.getAsyncJobs();
		String processorName = processorType?.getName();
		Assert.isTrue(results?.containsKey(processorName), 'Did not attempt to launch ' + processorName);
		Assert.areEqual(1, results?.get(processorName)?.size(), 'Wrong # of jobs launched: ' + processorName);
	}

	@IsTest
	static void shouldLaunchSpecifiedJobs() {
		Type processorType = MockAsyncActionProcessor.class;
		AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionProcessor__mdt config = AsyncActionTestUtils.initApexProcessor(processorType);
		MockAsyncActionProcessor processor = new MockAsyncActionProcessor();
		AsyncAction__c action = processor?.initAction();
		insert action;

		Test.startTest();
		Id jobId = new AsyncActionLauncher()?.launch(config);
		Test.stopTest();

		Assert.isNotNull(jobId, 'A job was not launched');
	}

	@IsTest
	static void shouldNotLaunchInvalidJob() {
		Type fakeProcessorType = Account.class; // Obv not a real processor!
		AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionTestUtils.initApexProcessor(fakeProcessorType);
		insert new AsyncAction__c(
			Processor__c = String.valueOf(fakeProcessorType),
			Scheduled__c = DateTime.now().addMinutes(-1),
			Status__c = 'Pending'
		);

		Test.startTest();
		new AsyncActionLauncher()?.launchAll();
		Test.stopTest();

		Map<String, List<AsyncApexJob>> results = AsyncActionLauncherTest.getAsyncJobs();
		String processorName = fakeProcessorType?.getName();
		Assert.isFalse(results?.containsKey(processorName), 'Launched a job for an invalid config');
	}

	@IsTest
	static void shouldNotLaunchIfDisabled() {
		Type processorType = MockAsyncActionProcessor.class;
		AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionProcessor__mdt config = AsyncActionTestUtils.initApexProcessor(processorType);
		config.Enabled__c = false;
		MockAsyncActionProcessor processor = new MockAsyncActionProcessor();
		AsyncAction__c action = processor?.initAction();
		insert action;

		Test.startTest();
		Id jobId = new AsyncActionLauncher()?.launch(config);
		Test.stopTest();

		Assert.isNull(jobId, 'Launched disabled job');
	}

	@IsTest
	static void shouldNotLaunchIfQueueableLimitsExceeded() {
		AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionProcessor__mdt config = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		AsyncActionProcessor processor = new MockAsyncActionProcessor();
		insert processor?.initAction();

		Test.startTest();
		// Spin up a bunch of queueable jobs, until the limit is met
		for (Integer i = 0; i < Limits.getLimitQueueableJobs(); i++) {
			System.enqueueJob(processor);
		}
		// NOW try to launch the job
		Id jobId = new AsyncActionLauncher()?.launch(config);
		Test.stopTest();

		Assert.isNull(jobId, 'A job was launched despite hitting queueable limits');
	}

	@IsTest
	static void shouldNotLaunchWithoutPendingActions() {
		AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionProcessor__mdt config = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		config.Enabled__c = false;
		// No actions inserted!

		Test.startTest();
		Id jobId = new AsyncActionLauncher()?.launch(config);
		Test.stopTest();

		Assert.isNull(jobId, 'A job was launched despite having no data');
	}

	@IsTest
	static void shouldNotLaunchDuplicateJob() {
		AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionProcessor__mdt config = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		AsyncAction__c action = new MockAsyncActionProcessor()?.initAction();
		insert action;

		Test.startTest();
		Id jobId1 = new AsyncActionLauncher()?.launch(config);
		Id jobId2 = new AsyncActionLauncher()?.launch(config);
		Test.stopTest();

		Assert.isNotNull(jobId1, 'Initial job was not launched');
		Assert.isNull(jobId2, 'Duplicate job was launched');
	}

	// **** HELPER **** //
	private static Map<String, List<AsyncApexJob>> getAsyncJobs() {
		Map<String, List<AsyncApexJob>> results = new Map<String, List<AsyncApexJob>>();
		for (AsyncApexJob job : [
			SELECT Id, ApexClass.Name
			FROM AsyncApexJob
			WHERE JobType = 'Queueable'
		]) {
			String className = job?.ApexClass?.Name;
			List<AsyncApexJob> matching = results?.get(className) ?? new List<AsyncApexJob>();
			matching?.add(job);
			results?.put(className, matching);
		}
		return results;
	}
}
