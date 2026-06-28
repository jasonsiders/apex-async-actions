@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class AsyncActionScheduleEnforcerTest {
	/** @description Cron expression firing nightly at 12:00 AM **/
	private static final String NIGHTLY_AT_MIDNIGHT = '0 0 0 * * ?';

	/** @description Cron expression firing nightly at 1:00 AM; used to simulate a misconfigured job **/
	private static final String NIGHTLY_AT_1AM = '0 0 1 * * ?';

	@IsTest
	static void shouldScheduleCustomJobsIfNoneExist() {
		AsyncActionScheduledJob__mdt jobSetting = AsyncActionScheduleEnforcerTest.initActiveJobSettings();
		jobSetting.CronExpression__c = NIGHTLY_AT_MIDNIGHT;
		jobSetting.Type__c = 'Custom';

		new AsyncActionScheduleEnforcer().enforce();

		List<AsyncApexJob> jobs = AsyncActionScheduleEnforcerTest.getActiveScheduledJobs();
		Assert.areEqual(1, jobs?.size(), 'Wrong # of jobs');
		AsyncApexJob job = jobs?.get(0);
		Assert.areEqual(jobSetting?.CronExpression__c, job?.CronTrigger?.CronExpression, 'Wrong CronExpression');
	}

	@IsTest
	static void shouldScheduleHourlyJobsIfNoneExist() {
		AsyncActionScheduledJob__mdt jobSetting = AsyncActionScheduleEnforcerTest.initActiveJobSettings();
		jobSetting.Type__c = 'Hourly';

		new AsyncActionScheduleEnforcer().enforce();

		List<AsyncApexJob> jobs = AsyncActionScheduleEnforcerTest.getActiveScheduledJobs();
		Assert.areEqual(1, jobs?.size(), 'Wrong # of jobs');
		AsyncApexJob job = jobs?.get(0);
		Assert.areEqual(
			AsyncActionScheduledJobUtils.HOURLY_CRON_EXP,
			job?.CronTrigger?.CronExpression,
			'Wrong CronExpression'
		);
	}

	@IsTest
	static void shouldScheduleSemiHourlyJobsIfNoneExist() {
		AsyncActionScheduledJob__mdt jobSetting = AsyncActionScheduleEnforcerTest.initActiveJobSettings();
		jobSetting.Interval__c = 10;
		jobSetting.Type__c = 'Semi-Hourly';

		new AsyncActionScheduleEnforcer().enforce();

		List<AsyncApexJob> jobs = AsyncActionScheduleEnforcerTest.getActiveScheduledJobs();
		Assert.areEqual(1, jobs?.size(), 'Wrong # of jobs');
		AsyncApexJob job = jobs?.get(0);
		Integer interval = jobSetting?.Interval__c?.intValue();
		Assert.areEqual(
			DateTime.now()?.addMinutes(interval).minute(),
			job?.CronTrigger?.NextFireTime?.minute(),
			'Wrong NextFireTime'
		);
	}

	@IsTest
	static void shouldAbortAndRescheduleCustomJob() {
		AsyncActionScheduledJob__mdt jobSetting = AsyncActionScheduleEnforcerTest.initActiveJobSettings();
		jobSetting.CronExpression__c = NIGHTLY_AT_MIDNIGHT;
		jobSetting.Type__c = 'Custom';
		// Schedule a job for the current settings record, but w/a different cron expression
		Id jobId = AsyncActionScheduleEnforcerTest.scheduleExistingJob(jobSetting, NIGHTLY_AT_1AM);

		new AsyncActionScheduleEnforcer().enforce();

		List<AsyncApexJob> jobs = AsyncActionScheduleEnforcerTest.getActiveScheduledJobs();
		Assert.areEqual(1, jobs?.size(), 'Wrong # of jobs');
		AsyncApexJob job = jobs?.get(0);
		Assert.areNotEqual(jobId, job?.CronTriggerId, 'Did not abort pre-existing jobId');
		Assert.areEqual(jobSetting?.CronExpression__c, job?.CronTrigger?.CronExpression, 'Wrong CronExpression');
	}

	@IsTest
	static void shouldAbortAndRescheduleHourlyJob() {
		AsyncActionScheduledJob__mdt jobSetting = AsyncActionScheduleEnforcerTest.initActiveJobSettings();
		jobSetting.Type__c = 'Hourly';
		// Schedule a job for the current settings record, but w/a different cron expression
		Id jobId = AsyncActionScheduleEnforcerTest.scheduleExistingJob(jobSetting, NIGHTLY_AT_MIDNIGHT);

		new AsyncActionScheduleEnforcer().enforce();

		List<AsyncApexJob> jobs = AsyncActionScheduleEnforcerTest.getActiveScheduledJobs();
		Assert.areEqual(1, jobs?.size(), 'Wrong # of jobs');
		AsyncApexJob job = jobs?.get(0);
		Assert.areNotEqual(jobId, job?.CronTriggerId, 'Did not abort pre-existing jobId');
		Assert.areEqual(
			AsyncActionScheduledJobUtils.HOURLY_CRON_EXP,
			job?.CronTrigger?.CronExpression,
			'Wrong CronExpression'
		);
	}

	@IsTest
	static void shouldAbortAndRescheduleSemiHourlyJob() {
		AsyncActionScheduledJob__mdt jobSetting = AsyncActionScheduleEnforcerTest.initActiveJobSettings();
		jobSetting.Interval__c = 5; // Every 5 minutes
		jobSetting.Type__c = 'Semi-Hourly';
		// Schedule a job for the current settings record, more than 5 minutes from now
		Integer tenMinsFromNow = DateTime.now()?.addMinutes(10)?.minute();
		String cron = '0 ' + tenMinsFromNow + ' * * * ?';
		Id jobId = AsyncActionScheduleEnforcerTest.scheduleExistingJob(jobSetting, cron);

		new AsyncActionScheduleEnforcer().enforce();

		List<AsyncApexJob> jobs = AsyncActionScheduleEnforcerTest.getActiveScheduledJobs();
		Assert.areEqual(1, jobs?.size(), 'Wrong # of jobs');
		AsyncApexJob job = jobs?.get(0);
		Assert.areNotEqual(jobId, job?.CronTriggerId, 'Did not abort pre-existing jobId');
		Integer interval = jobSetting?.Interval__c?.intValue();
		Integer nextMin = DateTime.now().addMinutes(interval)?.minute();
		String expectedCron = '0 ' + nextMin + ' * * * ?';
		Assert.areEqual(expectedCron, job?.CronTrigger?.CronExpression, 'Wrong CronExpression');
		Assert.areEqual(nextMin, job?.CronTrigger?.NextFireTime?.minute(), 'Wrong NextFireTime');
	}

	@IsTest
	static void shouldAbortJobsIfDisabled() {
		AsyncActionScheduledJob__mdt jobSetting = AsyncActionScheduleEnforcerTest.initActiveJobSettings();
		jobSetting.Enabled__c = false;
		AsyncActionScheduleEnforcerTest.scheduleExistingJob(jobSetting, NIGHTLY_AT_MIDNIGHT);

		new AsyncActionScheduleEnforcer().enforce();

		List<AsyncApexJob> jobs = AsyncActionScheduleEnforcerTest.getActiveScheduledJobs();
		Assert.areEqual(0, jobs?.size(), 'Wrong # of jobs');
	}

	@IsTest
	static void shouldDoNothingIfValidCustomJobExists() {
		AsyncActionScheduledJob__mdt jobSetting = AsyncActionScheduleEnforcerTest.initActiveJobSettings();
		jobSetting.CronExpression__c = NIGHTLY_AT_MIDNIGHT;
		jobSetting.Type__c = 'Custom';
		Id cronTriggerId = AsyncActionScheduleEnforcerTest.scheduleExistingJob(
			jobSetting,
			jobSetting?.CronExpression__c
		);

		new AsyncActionScheduleEnforcer().enforce();

		List<AsyncApexJob> jobs = AsyncActionScheduleEnforcerTest.getActiveScheduledJobs();
		Assert.areEqual(1, jobs?.size(), 'Wrong # of jobs');
		AsyncApexJob job = jobs?.get(0);
		Assert.areEqual(cronTriggerId, job?.CronTriggerId, 'Did not use pre-existing job');
	}

	@IsTest
	static void shouldDoNothingIfValidHourlyJobExists() {
		AsyncActionScheduledJob__mdt jobSetting = AsyncActionScheduleEnforcerTest.initActiveJobSettings();
		jobSetting.Type__c = 'Hourly';
		Id cronTriggerId = AsyncActionScheduleEnforcerTest.scheduleExistingJob(
			jobSetting,
			AsyncActionScheduledJobUtils.HOURLY_CRON_EXP
		);

		new AsyncActionScheduleEnforcer().enforce();

		List<AsyncApexJob> jobs = AsyncActionScheduleEnforcerTest.getActiveScheduledJobs();
		Assert.areEqual(1, jobs?.size(), 'Wrong # of jobs');
		AsyncApexJob job = jobs?.get(0);
		Assert.areEqual(cronTriggerId, job?.CronTriggerId, 'Did not use pre-existing job');
	}

	@IsTest
	static void shouldDoNothingIfValidSemiHourlyScheduledJobExists() {
		AsyncActionScheduledJob__mdt jobSetting = AsyncActionScheduleEnforcerTest.initActiveJobSettings();
		jobSetting.Interval__c = 10;
		jobSetting.Type__c = 'Semi-Hourly';
		Integer interval = jobSetting?.Interval__c?.intValue();
		Integer nextMin = DateTime.now().addMinutes(interval)?.minute();
		String cron = '0 ' + nextMin + ' * * * ?';
		Id cronTriggerId = AsyncActionScheduleEnforcerTest.scheduleExistingJob(jobSetting, cron);

		new AsyncActionScheduleEnforcer().enforce();

		List<AsyncApexJob> jobs = AsyncActionScheduleEnforcerTest.getActiveScheduledJobs();
		Assert.areEqual(1, jobs?.size(), 'Wrong # of jobs');
		AsyncApexJob job = jobs?.get(0);
		Assert.areEqual(cronTriggerId, job?.CronTriggerId, 'Did not use pre-existing job');
	}

	// **** HELPER **** //
	/**
	 * @description Returns all AsyncApexJob records for AsyncActionSchedulable that are currently active
	 * @return List of active scheduled AsyncApexJob records
	 */
	static List<AsyncApexJob> getActiveScheduledJobs() {
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
				ApexClass.Name = :AsyncActionSchedulable.class.getName()
				AND Status IN ('Holding', 'Queued', 'Preparing', 'Processing')
			WITH SYSTEM_MODE
			ORDER BY CreatedDate ASC
		];
	}

	/**
	 * @description Provisions an active scheduled job setting; AsyncActionTestUtils defaults to inactive
	 * @return An enabled AsyncActionScheduledJob__mdt record
	 */
	static AsyncActionScheduledJob__mdt initActiveJobSettings() {
		AsyncActionScheduledJob__mdt jobSetting = AsyncActionTestUtils.initScheduledJobSettings();
		jobSetting.Enabled__c = true;
		return jobSetting;
	}

	/**
	 * @description Schedules a job using the framework naming convention so enforce() will recognize it
	 * @param jobSetting The scheduled job settings to use for naming
	 * @param cron The cron expression to schedule the job with
	 * @return The Id of the created CronTrigger
	 */
	static Id scheduleExistingJob(AsyncActionScheduledJob__mdt jobSetting, String cron) {
		String jobName = AsyncActionScheduledJobUtils.SCHEDULED_JOB_PREFIX + jobSetting?.DeveloperName;
		return System.schedule(jobName, cron, new AsyncActionSchedulable(jobSetting));
	}
}
