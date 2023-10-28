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
			if (jobSettings?.Enabled__c == false) {
				// No jobs should exist for this class. Abort
				scheduler?.abortJobs(new List<AsyncApexJob>{pendingJob});
			} else if (pendingJob == null) {
				// Job is enabled, but one doesn't exist yet. Schedule one. 
				scheduler?.scheduleNewJob();
			} else if (pendingJob != null) {
				// Job is enabled, and job exists. Ensure that job respects the current interval. 
				Integer interval = jobSettings?.Interval__c?.intValue();
				if (pendingJob?.CronTrigger?.NextFireTime > DateTime.now()?.addMinutes(interval)) {
					// Out of range of the current interval. Abort it and schedule a new one
					scheduler?.abortJobs(new List<AsyncApexJob>{pendingJob});
					scheduler?.scheduleNewJob();
				} 
			}
		}
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
