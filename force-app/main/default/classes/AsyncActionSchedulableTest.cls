@IsTest
private class AsyncActionSchedulableTest {
	@IsTest
	static void shouldLaunchIfEnabled() {
		AsyncActionScheduledJob__mdt settings = AsyncActionTestUtils.initScheduledJobSettings('Test_Job');
		settings.Enabled__c = true;
		settings.Interval__c = 15;
		AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(MockAsyncActionProcessor.class);
		AsyncActionProcessor processor = new MockAsyncActionProcessor();
		insert processor?.initAction(null);

		new AsyncActionSchedulable(settings).execute(null);
		Test.getEventBus().deliver();

		// Should create 1 Queueable, and a future instance of the schedulable job
		Map<String, AsyncApexJob> jobsByClassName = new Map<String, AsyncApexJob>();
		for (AsyncApexJob job : AsyncActionSchedulableTest.getAsyncJobs()) {
			String className = job?.ApexClass?.Name;
			jobsByClassName?.put(className, job);
		}
		AsyncApexJob processorJob = jobsByClassName?.get('MockAsyncActionProcessor');
		Assert.isNotNull(processorJob, 'Processor job was not launched');
		AsyncApexJob scheduledJob = jobsByClassName?.get('AsyncActionSchedulable');
		Assert.isNotNull(scheduledJob, 'Job was not rescheduled');
		DateTime nextRun = scheduledJob?.CronTrigger?.NextFireTime;
		Assert.isTrue(nextRun > DateTime.now().addMinutes(14), 'Job was rescheduled <15 mins in future: ' + nextRun);
		Assert.isTrue(nextRun < DateTime.now().addMinutes(16), 'Job was rescheduled >15 mins in future: ' + nextRun);
	}

	@IsTest
	static void shouldNotLaunchIfDisabled() {
		AsyncActionScheduledJob__mdt settings = AsyncActionTestUtils.initScheduledJobSettings('Test_Job');
		settings.Enabled__c = false; // The scheduled job should do nothing
		settings.Interval__c = 15;
		AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(MockAsyncActionProcessor.class);
		AsyncActionProcessor processor = new MockAsyncActionProcessor();
		insert processor?.initAction(null);

		new AsyncActionSchedulable(settings).execute(null);
		Test.getEventBus().deliver();

		List<AsyncApexJob> jobs = AsyncActionSchedulableTest.getAsyncJobs();
		Assert.isTrue(jobs?.isEmpty(), 'Disabled, but job performed actions: ' + JSON.serialize(jobs));
	}

	// **** HELPER **** //
	static List<AsyncApexJob> getAsyncJobs() {
		return [SELECT ApexClass.Name, CronTrigger.NextFireTime FROM AsyncApexJob];
	}
}
