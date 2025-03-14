@IsTest
private class AsyncActionSchedulableTest {
	@IsTest
	static void shouldLaunchCustomCronIfEnabled() {
		AsyncActionProcessor__mdt actionSettings = AsyncActionTestUtils.initApexProcessor(
			MockAsyncActionProcessor.class
		);
		AsyncActionScheduledJob__mdt jobSettings = AsyncActionTestUtils.initScheduledJobSettings();
		jobSettings.CronExpression__c = '0 0 0 * * ?'; // Nightly at midnight
		jobSettings.Enabled__c = true;
		jobSettings.Type__c = 'Custom';
		AsyncActionScheduledJobItem__mdt jobItem = AsyncActionTestUtils.initScheduledJobItem(
			actionSettings,
			jobSettings
		);
		jobItem.Enabled__c = true;
		AsyncActionSchedulableTest.insertAction();

		new AsyncActionSchedulable(jobSettings).execute(null);
		Test.getEventBus().deliver();

		// Should create 1 Queueable, and a future instance of the schedulable job
		List<AsyncApexJob> asyncJobs = AsyncActionSchedulableTest.getAsyncJobs();
		Map<String, AsyncApexJob> jobsByClassName = AsyncActionSchedulableTest.mapAsyncJobsByClassName(asyncJobs);
		AsyncApexJob processorJob = jobsByClassName?.get(AsyncActionJob.class.getName());
		Assert.isNotNull(processorJob, 'Processor job was not launched');
		AsyncApexJob scheduledJob = jobsByClassName?.get(AsyncActionSchedulable.class.getName());
		Assert.isNotNull(scheduledJob, 'Job was not rescheduled');
		DateTime nextRun = scheduledJob?.CronTrigger?.NextFireTime;
		Assert.areEqual(Date.today()?.addDays(1), nextRun?.date(), 'Job was not rescheduled for tomorrow');
	}

	@IsTest
	static void shouldLaunchHourlyIfEnabled() {
		AsyncActionProcessor__mdt actionSettings = AsyncActionTestUtils.initApexProcessor(
			MockAsyncActionProcessor.class
		);
		AsyncActionSchedulableTest.insertAction();
		AsyncActionScheduledJob__mdt jobSettings = AsyncActionTestUtils.initScheduledJobSettings();
		jobSettings.Enabled__c = true;
		jobSettings.Type__c = 'Hourly';
		AsyncActionScheduledJobItem__mdt jobItem = AsyncActionTestUtils.initScheduledJobItem(
			actionSettings,
			jobSettings
		);
		jobItem.Enabled__c = true;
		AsyncActionSchedulableTest.insertAction();

		new AsyncActionSchedulable(jobSettings).execute(null);
		Test.getEventBus().deliver();

		// Should create 1 Queueable, and a future instance of the schedulable job
		List<AsyncApexJob> asyncJobs = AsyncActionSchedulableTest.getAsyncJobs();
		Map<String, AsyncApexJob> jobsByClassName = AsyncActionSchedulableTest.mapAsyncJobsByClassName(asyncJobs);
		AsyncApexJob processorJob = jobsByClassName?.get(AsyncActionJob.class.getName());
		Assert.isNotNull(processorJob, 'Processor job was not launched');
		AsyncApexJob scheduledJob = jobsByClassName?.get(AsyncActionSchedulable.class.getName());
		Assert.isNotNull(scheduledJob, 'Job was not rescheduled');
		DateTime nextRun = scheduledJob?.CronTrigger?.NextFireTime;
		Assert.areEqual(DateTime.now()?.addHours(1)?.hour(), nextRun?.hour(), 'Job was not rescheduled for next hour');
	}

	@IsTest
	static void shouldLaunchSemiHourlyIfEnabled() {
		AsyncActionProcessor__mdt actionSettings = AsyncActionTestUtils.initApexProcessor(
			MockAsyncActionProcessor.class
		);
		AsyncActionScheduledJob__mdt jobSettings = AsyncActionTestUtils.initScheduledJobSettings();
		jobSettings.Enabled__c = true;
		jobSettings.Interval__c = 15;
		jobSettings.Type__c = 'Semi-Hourly';
		AsyncActionScheduledJobItem__mdt jobItem = AsyncActionTestUtils.initScheduledJobItem(
			actionSettings,
			jobSettings
		);
		jobItem.Enabled__c = true;
		AsyncActionSchedulableTest.insertAction();

		new AsyncActionSchedulable(jobSettings).execute(null);
		Test.getEventBus().deliver();

		// Should create 1 Queueable, and a future instance of the schedulable job
		List<AsyncApexJob> asyncJobs = AsyncActionSchedulableTest.getAsyncJobs();
		Map<String, AsyncApexJob> jobsByClassName = AsyncActionSchedulableTest.mapAsyncJobsByClassName(asyncJobs);
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
		AsyncActionProcessor__mdt actionSettings = AsyncActionTestUtils.initApexProcessor(
			MockAsyncActionProcessor.class
		);
		AsyncActionScheduledJob__mdt jobSettings = AsyncActionTestUtils.initScheduledJobSettings();
		jobSettings.Enabled__c = false; // The scheduled job should do nothing
		jobSettings.Interval__c = 15;
		jobSettings.Type__c = 'Semi-Hourly';
		AsyncActionScheduledJobItem__mdt jobItem = AsyncActionTestUtils.initScheduledJobItem(
			actionSettings,
			jobSettings
		);
		jobItem.Enabled__c = true;
		AsyncActionSchedulableTest.insertAction();

		new AsyncActionSchedulable(jobSettings).execute(null);
		Test.getEventBus().deliver();

		// Neither a scheduled job or queueable should be created
		List<AsyncApexJob> jobs = AsyncActionSchedulableTest.getAsyncJobs();
		Assert.isTrue(jobs?.isEmpty(), 'Job disabled, but performed actions anyway');
	}

	@IsTest
	static void shouldNotLaunchIfJobItemIsDisabled() {
		AsyncActionProcessor__mdt actionSettings = AsyncActionTestUtils.initApexProcessor(
			MockAsyncActionProcessor.class
		);
		AsyncActionScheduledJob__mdt jobSettings = AsyncActionTestUtils.initScheduledJobSettings();
		jobSettings.Enabled__c = true;
		jobSettings.Interval__c = 15;
		jobSettings.Type__c = 'Semi-Hourly';
		AsyncActionScheduledJobItem__mdt jobItem = AsyncActionTestUtils.initScheduledJobItem(
			actionSettings,
			jobSettings
		);
		jobItem.Enabled__c = false; // Should not execute the action
		AsyncActionSchedulableTest.insertAction();

		new AsyncActionSchedulable(jobSettings).execute(null);
		Test.getEventBus().deliver();

		// Should create a new schedulable instance, but not a queueable one
		List<AsyncApexJob> asyncJobs = AsyncActionSchedulableTest.getAsyncJobs();
		Map<String, AsyncApexJob> jobsByClassName = AsyncActionSchedulableTest.mapAsyncJobsByClassName(asyncJobs);
		AsyncApexJob processorJob = jobsByClassName?.get(AsyncActionJob.class.getName());
		Assert.isNull(processorJob, 'Processor job');
		AsyncApexJob scheduledJob = jobsByClassName?.get(AsyncActionSchedulable.class.getName());
		Assert.isNotNull(scheduledJob, 'Job was not rescheduled');
	}

	@IsTest
	static void shouldNotLaunchIfNoJobItems() {
		AsyncActionScheduledJob__mdt jobSettings = AsyncActionTestUtils.initScheduledJobSettings();
		jobSettings.Enabled__c = true;
		jobSettings.Interval__c = 15;
		jobSettings.Type__c = 'Semi-Hourly';
		// No job items!
		AsyncActionSchedulableTest.insertAction();

		new AsyncActionSchedulable(jobSettings).execute(null);
		Test.getEventBus().deliver();

		// Should create a new schedulable instance, but not a queueable one
		List<AsyncApexJob> asyncJobs = AsyncActionSchedulableTest.getAsyncJobs();
		Map<String, AsyncApexJob> jobsByClassName = AsyncActionSchedulableTest.mapAsyncJobsByClassName(asyncJobs);
		AsyncApexJob processorJob = jobsByClassName?.get(AsyncActionJob.class.getName());
		Assert.isNull(processorJob, 'Processor job');
		AsyncApexJob scheduledJob = jobsByClassName?.get(AsyncActionSchedulable.class.getName());
		Assert.isNotNull(scheduledJob, 'Job was not rescheduled');
	}

	// **** HELPER **** //
	static List<AsyncApexJob> getAsyncJobs() {
		return [
			SELECT ApexClass.Name, JobType, CronTrigger.NextFireTime
			FROM AsyncApexJob
			WHERE ApexClass.Name IN (:AsyncActionJob.class.getName(), :AsyncActionSchedulable.class.getName())
			WITH SYSTEM_MODE
			LIMIT 50000
		];
	}

	static void insertAction() {
		// Insert an Async Action, make sure the triger doesn't run so we can test the logic separately
		AsyncActionTriggerFramework.disable(AsyncActionTriggerHandler.class);
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		AsyncAction__c action = AsyncActions.initAction(settings);
		Database.insert(action, System.AccessLevel.SYSTEM_MODE);
	}

	static Map<String, AsyncApexJob> mapAsyncJobsByClassName(List<AsyncApexJob> jobs) {
		Map<String, AsyncApexJob> jobsByClassName = new Map<String, AsyncApexJob>();
		for (AsyncApexJob job : jobs) {
			String className = job?.ApexClass?.Name;
			jobsByClassName?.put(className, job);
		}
		return jobsByClassName;
	}
}
