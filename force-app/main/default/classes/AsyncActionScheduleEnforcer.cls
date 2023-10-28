public class AsyncActionScheduleEnforcer {
	// This class can be called at any time to ensure that the Scheduled Jobs queue
	// is in alignment with the current AsyncActionScheduledJob__mdt records
	static final Logger LOGGER = new Logger()
		?.setLoggedFrom(AsyncActionScheduleEnforcer.class)
		?.setSource(AsyncActionConstants.PACKAGE_NAME);

	public void enforce() {
		Map<String, AsyncApexJob> pendingJobs = this.getPendingJobs();
		for (AsyncActionScheduledJob__mdt jobSettings : AsyncActionScheduledJobService.getAll()?.values()) {
			AsyncActionSchedulable scheduler = new AsyncActionSchedulable(jobSettings);
			String jobName = scheduler?.getJobName();
			AsyncApexJob pendingJob = pendingJobs?.get(jobName); 
			if (jobSettings?.Enabled__c == true) {
				// A scheduled job should exist in range of the configured interval
				Integer interval = jobSettings?.Interval__c?.intValue();
				if (this.getNextFireTime(pendingJob) > DateTime.now()?.addMinutes(interval)) {
					// Out of range of the current interval. Abort it and schedule a new one
					LOGGER?.finest('Aborting out of range job(s): ' + JSON.serialize(pendingJob));
					scheduler?.abortJobs(new List<AsyncApexJob>{pendingJob});
					scheduler?.scheduleNewJob();
				}
			} else {
				// No jobs should exist for this class
				scheduler?.abortJobs(new List<AsyncApexJob>{pendingJob});
			}
		}
	}

	private DateTime getNextFireTime(AsyncApexJob job) {
		Integer interval = AsyncActionSettingService.getScheduledInterval();
		return (job != null) ? job?.CronTrigger?.NextFireTime : DateTime.now().addMinutes(interval);
	}

	private Map<String, AsyncApexJob> getPendingJobs() {
		Map<String, AsyncApexJob> pendingJobs = new Map<String, AsyncApexJob>(); 
		for (AsyncApexJob job : [
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
				ApexClass.Name = :AsyncActionSchedulable.class.getName()
				AND Status IN ('Holding', 'Queued', 'Preparing', 'Processing')
			ORDER BY CronTrigger.NextFireTime ASC
		]) {
			String jobName = job?.CronTrigger?.CronJobDetail?.Name; 
			pendingJobs?.put(jobName, job); 
		}
		return pendingJobs;
	}
}
