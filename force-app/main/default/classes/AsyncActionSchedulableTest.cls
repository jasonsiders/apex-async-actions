@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,CPD.DetectCopyPasteForApex')
@IsTest
private class AsyncActionSchedulableTest {
	private static AsyncActionProcessor__mdt actionSettings;
	private static AsyncActionScheduledJob__mdt jobSettings;
	private static AsyncActionScheduledJobItem__mdt jobItem;
	static {
		AsyncActionSchedulableTest.insertAction();
		Type mock = MockAsyncActionProcessor.class;
		actionSettings = AsyncActionTestUtils.initApexProcessor(mock);
		jobSettings = AsyncActionTestUtils.initScheduledJobSettings();
		jobSettings.Enabled__c = true;
		jobSettings.CronExpression__c = '0 0 0 * * ?'; // Nightly at midnight
		jobSettings.Type__c = 'Custom';
		jobItem = AsyncActionTestUtils.initScheduledJobItem(actionSettings, jobSettings);
		jobItem.Enabled__c = true;
	}

	@IsTest
	static void shouldLaunchCustomCronIfEnabled() {
		jobSettings.Type__c = 'Custom';

		new AsyncActionSchedulable(jobSettings).execute(null);
		Test.getEventBus().deliver();

		// Should create 1 Queueable, and a future instance of the schedulable job
		Map<String, AsyncApexJob> jobsByClassName = AsyncActionSchedulableTest.getAsyncJobs();
		AsyncApexJob processorJob = jobsByClassName?.get(AsyncActionJob.class.getName());
		Assert.isNotNull(processorJob, 'Processor job was not launched');
		AsyncApexJob scheduledJob = jobsByClassName?.get(AsyncActionSchedulable.class.getName());
		Assert.isNotNull(scheduledJob, 'Job was not rescheduled');
		DateTime nextRun = scheduledJob?.CronTrigger?.NextFireTime;
		Assert.areEqual(Date.today()?.addDays(1), nextRun?.date(), 'Job was not rescheduled for tomorrow');
	}

	@IsTest
	static void shouldLaunchHourlyIfEnabled() {
		jobSettings.Type__c = 'Hourly';

		new AsyncActionSchedulable(jobSettings).execute(null);
		Test.getEventBus().deliver();

		// Should create 1 Queueable, and a future instance of the schedulable job
		Map<String, AsyncApexJob> jobsByClassName = AsyncActionSchedulableTest.getAsyncJobs();
		AsyncApexJob processorJob = jobsByClassName?.get(AsyncActionJob.class.getName());
		Assert.isNotNull(processorJob, 'Processor job was not launched');
		AsyncApexJob scheduledJob = jobsByClassName?.get(AsyncActionSchedulable.class.getName());
		Assert.isNotNull(scheduledJob, 'Job was not rescheduled');
		DateTime nextRun = scheduledJob?.CronTrigger?.NextFireTime;
		Assert.areEqual(DateTime.now()?.addHours(1)?.hour(), nextRun?.hour(), 'Job was not rescheduled for next hour');
	}

	@IsTest
	static void shouldLaunchSemiHourlyIfEnabled() {
		jobSettings.Interval__c = 15;
		jobSettings.Type__c = 'Semi-Hourly';

		new AsyncActionSchedulable(jobSettings).execute(null);
		Test.getEventBus().deliver();

		// Should create 1 Queueable, and a future instance of the schedulable job
		Map<String, AsyncApexJob> jobsByClassName = AsyncActionSchedulableTest.getAsyncJobs();
		AsyncApexJob processorJob = jobsByClassName?.get(AsyncActionJob.class.getName());
		Assert.isNotNull(processorJob, 'Processor job was not launched');
		AsyncApexJob scheduledJob = jobsByClassName?.get(AsyncActionSchedulable.class.getName());
		Assert.isNotNull(scheduledJob, 'Job was not rescheduled');
		DateTime nextRun = scheduledJob?.CronTrigger?.NextFireTime;
		Assert.isTrue(nextRun > DateTime.now().addMinutes(14), 'Job was rescheduled <15 mins in future: ' + nextRun);
		Assert.isTrue(nextRun < DateTime.now().addMinutes(16), 'Job was rescheduled >15 mins in future: ' + nextRun);
	}

	@IsTest
	static void shouldNotLaunchIfJobIsDisabled() {
		jobSettings.Enabled__c = false; // The scheduled job should do nothing

		new AsyncActionSchedulable(jobSettings).execute(null);
		Test.getEventBus().deliver();

		// Neither a scheduled job or queueable should be created
		Map<String, AsyncApexJob> jobs = AsyncActionSchedulableTest.getAsyncJobs();
		Assert.isTrue(jobs?.isEmpty(), 'Job disabled, but performed actions anyway');
	}

	@IsTest
	static void shouldNotLaunchIfJobItemIsDisabled() {
		jobItem.Enabled__c = false; // Should not execute the action

		new AsyncActionSchedulable(jobSettings).execute(null);
		Test.getEventBus().deliver();

		// Should create a new schedulable instance, but not a queueable one
		Map<String, AsyncApexJob> jobsByClassName = AsyncActionSchedulableTest.getAsyncJobs();
		AsyncApexJob processorJob = jobsByClassName?.get(AsyncActionJob.class.getName());
		Assert.isNull(processorJob, 'Processor job');
		AsyncApexJob scheduledJob = jobsByClassName?.get(AsyncActionSchedulable.class.getName());
		Assert.isNotNull(scheduledJob, 'Job was not rescheduled');
	}

	@IsTest
	static void shouldNotLaunchIfNoJobItems() {
		AsyncActionScheduledJobItemService.jobItems = new Map<String, List<AsyncActionScheduledJobItem__mdt>>{};

		new AsyncActionSchedulable(jobSettings).execute(null);
		Test.getEventBus().deliver();

		// Should create a new schedulable instance, but not a queueable one
		Map<String, AsyncApexJob> jobsByClassName = AsyncActionSchedulableTest.getAsyncJobs();
		AsyncApexJob processorJob = jobsByClassName?.get(AsyncActionJob.class.getName());
		Assert.isNull(processorJob, 'Processor job');
		AsyncApexJob scheduledJob = jobsByClassName?.get(AsyncActionSchedulable.class.getName());
		Assert.isNotNull(scheduledJob, 'Job was not rescheduled');
	}

	// **** HELPER **** //
	static void insertAction() {
		// Insert an Async Action, make sure the triger doesn't run so we can test the logic separately
		AsyncActionTriggerFramework.disable(AsyncActionTriggerHandler.class);
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		AsyncAction__c action = AsyncActions.initAction(settings);
		Database.insert(action, System.AccessLevel.SYSTEM_MODE);
	}

	static Map<String, AsyncApexJob> getAsyncJobs() {
		Map<String, AsyncApexJob> jobsByClassName = new Map<String, AsyncApexJob>{};
		for (AsyncApexJob job : [
			SELECT ApexClass.Name, JobType, CronTrigger.NextFireTime
			FROM AsyncApexJob
			WHERE ApexClass.Name IN (:AsyncActionJob.class.getName(), :AsyncActionSchedulable.class.getName())
			WITH SYSTEM_MODE
			LIMIT 50000
		]) {
			String className = job?.ApexClass?.Name;
			jobsByClassName?.put(className, job);
		}
		return jobsByClassName;
	}
}
