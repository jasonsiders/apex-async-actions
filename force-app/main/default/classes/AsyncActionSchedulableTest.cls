@IsTest
private class AsyncActionSchedulableTest {
	@IsTest
	static void shouldLaunchIfEnabled() {
		AsyncActionProcessor__mdt actionSettings = AsyncActionTestUtils.initProcessorSettings(MockAsyncActionProcessor.class);
		AsyncActionScheduledJob__mdt jobSettings = AsyncActionTestUtils.initScheduledJobSettings();
		jobSettings.Enabled__c = true;
		jobSettings.Interval__c = 15;
		AsyncActionScheduledJobItem__mdt jobItem = AsyncActionTestUtils.initScheduledJobItem(actionSettings, jobSettings); 
		jobItem.Enabled__c = true; 
		AsyncActionProcessor processor = new MockAsyncActionProcessor();
		insert processor?.initAction(null);

		new AsyncActionSchedulable(jobSettings).execute(null);
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
	static void shouldNotLaunchIfJobIsDisabled() {
		AsyncActionProcessor__mdt actionSettings = AsyncActionTestUtils.initProcessorSettings(MockAsyncActionProcessor.class);
		AsyncActionScheduledJob__mdt jobSettings = AsyncActionTestUtils.initScheduledJobSettings();
		jobSettings.Enabled__c = false; // The scheduled job should do nothing
		jobSettings.Interval__c = 15;
		AsyncActionScheduledJobItem__mdt jobItem = AsyncActionTestUtils.initScheduledJobItem(actionSettings, jobSettings); 
		jobItem.Enabled__c = true; 
		AsyncActionProcessor processor = new MockAsyncActionProcessor();
		insert processor?.initAction(null);

		new AsyncActionSchedulable(jobSettings).execute(null);
		Test.getEventBus().deliver();

		List<AsyncApexJob> jobs = AsyncActionSchedulableTest.getAsyncJobs();
		Assert.isTrue(jobs?.isEmpty(), 'Job disabled, but performed actions anyway');
	}

	@IsTest
	static void shouldNotLaunchIfJobItemIsDisabled() {
		AsyncActionProcessor__mdt actionSettings = AsyncActionTestUtils.initProcessorSettings(MockAsyncActionProcessor.class);
		AsyncActionScheduledJob__mdt jobSettings = AsyncActionTestUtils.initScheduledJobSettings();
		jobSettings.Enabled__c = true; 
		jobSettings.Interval__c = 15;
		AsyncActionScheduledJobItem__mdt jobItem = AsyncActionTestUtils.initScheduledJobItem(actionSettings, jobSettings); 
		jobItem.Enabled__c = false; // Should not execute the action
		AsyncActionProcessor processor = new MockAsyncActionProcessor();
		insert processor?.initAction(null);

		new AsyncActionSchedulable(jobSettings).execute(null);
		Test.getEventBus().deliver();

		List<AsyncApexJob> jobs = AsyncActionSchedulableTest.getAsyncJobs();
		Assert.isTrue(jobs?.isEmpty(), 'Job Item Disabled, but performed actions anyway');
	}

	@IsTest 
	static void shouldNotLaunchIfNoJobItems() {
		AsyncActionProcessor__mdt actionSettings = AsyncActionTestUtils.initProcessorSettings(MockAsyncActionProcessor.class);
		AsyncActionScheduledJob__mdt jobSettings = AsyncActionTestUtils.initScheduledJobSettings();
		jobSettings.Enabled__c = true; 
		jobSettings.Interval__c = 15;
		// No job items!
		AsyncActionScheduledJobItem__mdt jobItem = AsyncActionTestUtils.initScheduledJobItem(actionSettings, jobSettings); 
		jobItem.Enabled__c = false; // Should not execute the action
		AsyncActionProcessor processor = new MockAsyncActionProcessor();
		insert processor?.initAction(null);

		new AsyncActionSchedulable(jobSettings).execute(null);
		Test.getEventBus().deliver();

		List<AsyncApexJob> jobs = AsyncActionSchedulableTest.getAsyncJobs();
		Assert.isTrue(jobs?.isEmpty(), 'Action was not added to the job, but performed actions anyway');
	}

	// **** HELPER **** //
	static List<AsyncApexJob> getAsyncJobs() {
		return [SELECT ApexClass.Name, CronTrigger.NextFireTime FROM AsyncApexJob];
	}
}
