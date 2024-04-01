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
			Assert.areEqual(
				DateTime.now()?.addMinutes(interval).minute(),
				job?.CronTrigger?.NextFireTime?.minute(),
				'Wrong NextFireTime'
			);
		}
	}

	@IsTest
	static void shouldRescheduleJobsIfNoneInRange() {
		Map<String, AsyncActionScheduledJob__mdt> jobSettings = AsyncActionScheduleEnforcerTest.initJobSettings();
		// For each jobSetting, create a scheduled job that is "out-of-range" of the current interval.
		// These existing jobs should be aborted and replaced with a job that respects the current interval.
		Set<Id> existingJobIds = new Set<Id>();
		for (AsyncActionScheduledJob__mdt jobSetting : jobSettings?.values()) {
			String jobName = AsyncActionSchedulable.JOB_PREFIX + jobSetting?.Id;
			Integer minsToAdd = jobSetting?.Interval__c?.intValue() + 5; // Out of range!
			Integer nextMin = DateTime.now().addMinutes(minsToAdd)?.minute();
			String cronExp = '0 ' + nextMin + ' * * * ?';
			System.Schedulable job = new AsyncActionSchedulable(jobSetting);
			Id jobId = System.schedule(jobName, cronExp, job);
			existingJobIds?.add(jobId);
		}

		new AsyncActionScheduleEnforcer().enforce();

		List<AsyncApexJob> jobs = AsyncActionScheduleEnforcerTest.getScheduledJobs();
		Assert.areEqual(jobSettings?.size(), jobs?.size(), 'Wrong # of Scheduled Jobs');
		for (AsyncApexJob job : jobs) {
			Assert.isFalse(existingJobIds?.contains(job?.CronTriggerId), 'Out-of-range job was not aborted');
			String key = job?.CronTrigger?.CronJobDetail?.Name?.replace(AsyncActionSchedulable.JOB_PREFIX, '');
			AsyncActionScheduledJob__mdt jobSetting = jobSettings?.get(key);
			Assert.isNotNull(jobSetting, 'Could not find a matching AsyncActionScheduledJob__mdt: ' + key);
			Integer interval = jobSetting?.Interval__c?.intValue();
			Assert.areEqual(
				DateTime.now()?.addMinutes(interval).minute(),
				job?.CronTrigger?.NextFireTime?.minute(),
				'Wrong NextFireTime'
			);
		}
	}

	@IsTest
	static void shouldAbortJobsIfDisabled() {
		Map<String, AsyncActionScheduledJob__mdt> jobSettings = AsyncActionScheduleEnforcerTest.initJobSettings();
		for (AsyncActionScheduledJob__mdt jobSetting : jobSettings?.values()) {
			String jobName = AsyncActionSchedulable.JOB_PREFIX + jobSetting?.Id;
			Integer minsToAdd = jobSetting?.Interval__c?.intValue() - 2; // In range!
			Integer nextMin = DateTime.now().addMinutes(minsToAdd)?.minute();
			String cronExp = '0 ' + nextMin + ' * * * ?';
			System.Schedulable job = new AsyncActionSchedulable(jobSetting);
			Id jobId = System.schedule(jobName, cronExp, job);
		}
		// Disable one of the jobs
		AsyncActionScheduledJob__mdt disabledJob = jobSettings?.values()[0];
		disabledJob.Enabled__c = false;

		new AsyncActionScheduleEnforcer().enforce();

		List<AsyncApexJob> jobs = AsyncActionScheduleEnforcerTest.getScheduledJobs();
		Assert.areEqual(jobSettings?.size() - 1, jobs?.size(), 'Wrong # of Scheduled Jobs');
		for (AsyncApexJob job : jobs) {
			String key = job?.CronTrigger?.CronJobDetail?.Name?.replace(AsyncActionSchedulable.JOB_PREFIX, '');
			Assert.areNotEqual(disabledJob?.Id, key, 'Disabled job was scheduled');
		}
	}

	@IsTest
	static void shouldDoNothingIfNoJobsAndDisabled() {
		Map<String, AsyncActionScheduledJob__mdt> jobSettings = AsyncActionScheduleEnforcerTest.initJobSettings();
		AsyncActionScheduledJob__mdt disabledJob = jobSettings?.values()[0];
		disabledJob.Enabled__c = false;

		new AsyncActionScheduleEnforcer().enforce();

		List<AsyncApexJob> jobs = AsyncActionScheduleEnforcerTest.getScheduledJobs();
		Assert.areEqual(jobSettings?.size() - 1, jobs?.size(), 'Wrong # of Scheduled Jobs');
		for (AsyncApexJob job : jobs) {
			String key = job?.CronTrigger?.CronJobDetail?.Name?.replace(AsyncActionSchedulable.JOB_PREFIX, '');
			Assert.areNotEqual(disabledJob?.Id, key, 'Disabled job was scheduled');
		}
	}

	@IsTest
	static void shouldDoNothingIfScheduledJobExistsInRange() {
		Map<String, AsyncActionScheduledJob__mdt> jobSettings = AsyncActionScheduleEnforcerTest.initJobSettings();
		Set<Id> existingJobIds = new Set<Id>();
		for (AsyncActionScheduledJob__mdt jobSetting : jobSettings?.values()) {
			String jobName = AsyncActionSchedulable.JOB_PREFIX + jobSetting?.Id;
			Integer minsToAdd = jobSetting?.Interval__c?.intValue() - 2; // In range!
			Integer nextMin = DateTime.now().addMinutes(minsToAdd)?.minute();
			String cronExp = '0 ' + nextMin + ' * * * ?';
			System.Schedulable job = new AsyncActionSchedulable(jobSetting);
			Id jobId = System.schedule(jobName, cronExp, job);
			existingJobIds?.add(jobId);
		}

		new AsyncActionScheduleEnforcer().enforce();

		List<AsyncApexJob> jobs = AsyncActionScheduleEnforcerTest.getScheduledJobs();
		Assert.areEqual(jobSettings?.size(), jobs?.size(), 'Wrong # of Scheduled Jobs');
		for (AsyncApexJob job : jobs) {
			Assert.isTrue(existingJobIds?.contains(job?.CronTriggerId), 'Did not keep existing job');
		}
	}

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
		for (Double interval : new List<Double>{ 10, 20, 30 }) {
			AsyncActionScheduledJob__mdt jobSetting = AsyncActionTestUtils.initScheduledJobSettings();
			jobSetting.Enabled__c = true;
			jobSetting.Interval__c = interval;
		}
		return AsyncActionScheduledJobService.getAll();
	}
}
