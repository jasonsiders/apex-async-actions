public class AsyncActionScheduleEnforcer {
	// This class can be called at any time to ensure that the Scheduled Jobs queue
	// is in alignment with the current AsyncActionSetting__mdt configuration
	AsyncApexJob nextJob;
	Set<AsyncApexJob> jobsToAbort = new Set<AsyncApexJob>();
	AsyncActionSchedulable scheduler = new AsyncActionSchedulable();
	static final Logger LOGGER = new Logger()
		?.setLoggedFrom(AsyncActionScheduleEnforcer.class)
		?.setSource(AsyncActionConstants.PACKAGE_NAME);

	public void enforce() {
		List<AsyncApexJob> jobs = this.getPendingJobs();
		if (AsyncActionSettingService.getSettings()?.RunScheduledJob__c == true) {
			// A scheduled job should exist in range of the configured interval
			this.ensureActiveJobs(jobs);
		} else {
			// No jobs should exist for this class
			this.scheduler?.abortJobs(jobs);
		}
	}

	private void abortJobs() {
		this.jobsToAbort?.remove(null); // Avoid processing null values
		if (this.jobsToAbort?.isEmpty() == false) {
			LOGGER?.finest('Aborting out of range job(s): ' + JSON.serialize(this.jobsToAbort));
		}
		this.scheduler?.abortJobs(new List<AsyncApexJob>(jobsToAbort));
	}

	private void ensureActiveJobs(List<AsyncApexJob> jobs) {
		// A single job should exist "in range" - between now and the next interval time
		// If no jobs in range, create one
		// Abort any jobs that are not in range
		// If multiple jobs in range, abort all but the most recent
		for (AsyncApexJob currentJob : jobs) {
			if (this.getNextFireTime(currentJob) > this.getNextFireTime(nextJob)) {
				// Out of range, or older than the next job. Abort it.
				this.jobsToAbort?.add(currentJob);
			} else {
				// In range & more recent than the next job. Keep it, and replace the "old" nextJob.
				this.jobsToAbort?.add(nextJob);
				this.nextJob = currentJob;
			}
		}
		this.abortJobs();
		if (nextJob == null) {
			LOGGER?.finest('Creating new instance of ' + AsyncActionSchedulable.class);
			this.scheduler?.scheduleNewJob();
		}
	}

	private DateTime getNextFireTime(AsyncApexJob job) {
		Integer interval = AsyncActionSettingService.getScheduledInterval();
		return (job != null) ? job?.CronTrigger?.NextFireTime : DateTime.now().addMinutes(interval);
	}

	private List<AsyncApexJob> getPendingJobs() {
		return [
			SELECT
				Id,
				ApexClass.Name,
				CreatedDate,
				CronTriggerId,
				CronTrigger.CronJobDetail.Name,
				CronTrigger.NextFireTime,
				Status
			FROM AsyncApexJob
			WHERE
				ApexClass.Name = 'AsyncActionSchedulable'
				AND Status IN ('Holding', 'Queued', 'Preparing', 'Processing')
			ORDER BY CronTrigger.NextFireTime ASC
		];
	}
}
