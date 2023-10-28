@IsTest
private class AsyncActionScheduleEnforcerTest {
	@IsTest 
	static void shouldScheduleJobsIfNoneExist() {
		Map<String, AsyncActionScheduledJob__mdt> jobSettings = AsyncActionScheduleEnforcerTest.initJobSettings();

		new AsyncActionScheduleEnforcer().enforce();

		List<AsyncApexJob> jobs = AsyncActionScheduleEnforcerTest.getScheduledJobs();
		Assert.areEqual(jobSettings?.size(), jobs?.size(), 'Wrong # of Scheduled Jobs'); 
		for (AsyncApexJob job : jobs) {
			String key = job?.CronTrigger?.CronJobDetail?.Name?.replace(AsyncActionSchedulable.JOB_PREFIX, ''); 
			AsyncActionScheduledJob__mdt jobSetting = jobSettings?.get(key);
			Assert.isNotNull(jobSetting, 'Could not find a matching AsyncActionScheduledJob__mdt: ' + key);
			Integer interval = jobSetting?.Interval__c?.intValue();
			Assert.areEqual(DateTime.now()?.addMinutes(interval).minute(), job?.CronTrigger?.NextFireTime?.minute(), 'Wrong NextFireTime');
		}
	}

	/* @IsTest
	static void shouldScheduleJobsIfNoneExist() {
		Integer interval = 15;
		AsyncActionScheduledJob__mdt settings = AsyncActionTestUtils.initScheduledJobSettings();
		settings.Enabled__c = true;
		settings.Interval__c = Decimal.valueOf(interval);

		new AsyncActionScheduleEnforcer().enforce();

		List<AsyncApexJob> jobs = AsyncActionScheduleEnforcerTest.getScheduledJobs();
		Assert.areEqual(1, jobs?.size(), 'Wrong # of scheduled jobs');
		AsyncApexJob job = jobs[0];
		Assert.areEqual(
			DateTime.now().addMinutes(interval).minute(),
			job?.CronTrigger?.NextFireTime?.minute(),
			'Wrong NextFireTime'
		);
	}

	@IsTest
	static void shouldRescheduleJobsIfNoneInRange() {
		Integer interval = 15;
		AsyncActionScheduledJob__mdt settings = AsyncActionTestUtils.initScheduledJobSettings();
		settings.Enabled__c = true;
		settings.Interval__c = Decimal.valueOf(interval);
		// Schedule a job for > 15 mins in the future
		Integer nextMin = DateTime.now().addMinutes(20).minute();
		String originalJobName = 'OriginalJob';
		String cronExp = '0 ' + nextMin + ' * * * ?';
		System.schedule(originalJobName, cronExp, new AsyncActionSchedulable(settings));

		new AsyncActionScheduleEnforcer().enforce();

		List<AsyncApexJob> jobs = AsyncActionScheduleEnforcerTest.getScheduledJobs();
		Assert.areEqual(1, jobs?.size(), 'Wrong # of scheduled jobs');
		AsyncApexJob job = jobs[0];
		Assert.areNotEqual(originalJobName, job?.CronTrigger?.CronJobDetail?.Name, 'New job did not replace original');
		Assert.areEqual(
			DateTime.now().addMinutes(interval).minute(),
			job?.CronTrigger?.NextFireTime?.minute(),
			'Wrong NextFireTime'
		);
	}

	@IsTest
	static void shouldAbortJobsIfDisabled() {
		AsyncActionScheduledJob__mdt settings = AsyncActionTestUtils.initScheduledJobSettings();
		settings.Enabled__c = false;
		// Schedule a pre-existing job
		Integer nextMin = DateTime.now().addMinutes(20).minute();
		String originalJobName = 'OriginalJob';
		String cronExp = '0 ' + nextMin + ' * * * ?';
		System.schedule(originalJobName, cronExp, new AsyncActionSchedulable(settings));

		new AsyncActionScheduleEnforcer().enforce();

		List<AsyncApexJob> jobs = AsyncActionScheduleEnforcerTest.getScheduledJobs();
		Assert.areEqual(0, jobs?.size(), 'Wrong # of scheduled jobs');
	}

	@IsTest
	static void shouldDoNothingIfNoJobsAndDisabled() {
		AsyncActionScheduledJob__mdt settings = AsyncActionTestUtils.initScheduledJobSettings();
		settings.Enabled__c = false;

		new AsyncActionScheduleEnforcer().enforce();

		List<AsyncApexJob> jobs = AsyncActionScheduleEnforcerTest.getScheduledJobs();
		Assert.areEqual(0, jobs?.size(), 'Wrong # of scheduled jobs');
	}

	@IsTest
	static void shouldDoNothingIfScheduledJobExistsInRange() {
		Integer interval = 15;
		AsyncActionScheduledJob__mdt settings = AsyncActionTestUtils.initScheduledJobSettings();
		settings.Enabled__c = true;
		settings.Interval__c = Decimal.valueOf(interval);
		// Schedule a job for < 15 mins in the future
		String originalJobName = 'OriginalJob';
		Integer nextMin = DateTime.now().addMinutes(10).minute();
		String cronExp = '0 ' + nextMin + ' * * * ?';
		System.schedule(originalJobName, cronExp, new AsyncActionSchedulable(settings));

		new AsyncActionScheduleEnforcer().enforce();

		List<AsyncApexJob> jobs = AsyncActionScheduleEnforcerTest.getScheduledJobs();
		Assert.areEqual(1, jobs?.size(), 'Wrong # of scheduled jobs');
		AsyncApexJob job = jobs[0];
		Assert.areEqual(nextMin, job?.CronTrigger?.NextFireTime?.minute(), 'Wrong NextFireTime');
		Assert.areEqual(originalJobName, job?.CronTrigger?.CronJobDetail?.Name, 'Job was rescheduled');
	}

	@IsTest
	static void shouldRemoveMultipleDuplicateJobs() {
		Integer interval = 15;
		AsyncActionScheduledJob__mdt settings = AsyncActionTestUtils.initScheduledJobSettings();
		settings.Enabled__c = true;
		settings.Interval__c = Decimal.valueOf(interval);
		// Schedule multiple jobs for < 15 mins in the future
		String jobName1 = 'Job1';
		Integer nextMin1 = DateTime.now().addMinutes(10).minute();
		String cronExp1 = '0 ' + nextMin1 + ' * * * ?';
		System.schedule(jobName1, cronExp1, new AsyncActionSchedulable(settings));
		String jobName2 = 'Job2';
		Integer nextMin2 = DateTime.now().addMinutes(5).minute();
		String cronExp2 = '0 ' + nextMin2 + ' * * * ?';
		System.schedule(jobName2, cronExp2, new AsyncActionSchedulable(settings));

		new AsyncActionScheduleEnforcer().enforce();

		List<AsyncApexJob> jobs = AsyncActionScheduleEnforcerTest.getScheduledJobs();
		Assert.areEqual(1, jobs?.size(), 'Wrong # of scheduled jobs');
		// Since multiple exist, abort all but the one for the earliest time
		AsyncApexJob job = jobs[0];
		Assert.areEqual(nextMin2, job?.CronTrigger?.NextFireTime?.minute(), 'Wrong NextFireTime');
		Assert.areEqual(jobName2, job?.CronTrigger?.CronJobDetail?.Name, 'Wrong Job was kept');
	} */

	// **** HELPER **** //
	static List<AsyncApexJob> getScheduledJobs() {
		return [
			SELECT
				Id,
				CronTriggerId,
				CronTrigger.CronExpression,
				CronTrigger.CronJobDetail.Name,
				CronTrigger.NextFireTime,
				Status
			FROM AsyncApexJob
			WHERE
				ApexClass.Name = 'AsyncActionSchedulable'
				AND Status IN ('Holding', 'Queued', 'Preparing', 'Processing')
			ORDER BY CreatedDate ASC
		];
	}

	static Map<String, AsyncActionScheduledJob__mdt> initJobSettings() {
		for (Double interval : new List<Double>{ 10, 20, 30, 60 }) {
			AsyncActionScheduledJob__mdt jobSetting = AsyncActionTestUtils.initScheduledJobSettings();
			jobSetting.Enabled__c = true; 
			jobSetting.Interval__c = interval;
		}
		return AsyncActionScheduledJobService.getAll();
	}
}
