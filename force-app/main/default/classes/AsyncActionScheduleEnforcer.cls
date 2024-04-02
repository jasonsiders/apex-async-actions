public class AsyncActionScheduleEnforcer {
	// This class can be called at any time to ensure that the Scheduled Jobs queue
	// is in alignment with the current AsyncActionScheduledJob__mdt records
	public void enforce() {
		// Ensures that AsyncApexJobs created by the framework matches the current AsyncActionScheduledJob__mdt configuration
		// 1. Map scheduled jobs by the expected job name
		Map<String, JobWrapper> jobs = new Map<String, JobWrapper>();
		for (AsyncActionScheduledJob__mdt jobSettings : AsyncActionScheduledJobService.getAll()?.values()) {
			if (jobSettings?.Enabled__c == true) {
				JobWrapper wrapper = new JobWrapper(jobSettings);
				String jobName = wrapper?.getJobName();
				jobs?.put(jobName, wrapper);
			}
		}
		// 2. Query for and add asyncapexjobs to the wrappers, processing them
		for (AsyncApexJob asyncJob : this.getPendingJobs()) {
			String jobName = asyncJob?.CronTrigger?.CronJobDetail?.Name;
			JobWrapper wrapper = jobs?.get(jobName)?.addAsyncJob(asyncJob);
			if (wrapper == null) {
				// A corresponding job does not exist, or is not active. Abort it
				AsyncActionScheduledJobUtils.abortJobs(asyncJob);
			}
		}
		// 3. Iterate through the jobs and ensure that they are configured for the correct intervals
		for (JobWrapper job : jobs?.values()) {
			job?.validate();
		}
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
				ApexClass.Name = :AsyncActionSchedulable.class.getName()
				AND Status IN ('Holding', 'Queued', 'Preparing', 'Processing')
			ORDER BY CronTrigger.NextFireTime ASC
		];
	}
	
	private class JobWrapper {
		AsyncApexJob asyncJob; 
		Integer interval; 
		AsyncActionScheduledJob__mdt jobSettings;
		AsyncActionSchedulable scheduler; 

		public JobWrapper(AsyncActionScheduledJob__mdt jobSettings) {
			this.jobSettings = jobSettings;
			this.interval = jobSettings?.Interval__c?.intValue();
			this.scheduler = new AsyncActionSchedulable(jobSettings);
		}

		public JobWrapper addAsyncJob(AsyncApexJob asyncJob) {
			this.asyncJob = asyncJob; 
			return this;
		}

		public String getJobName() {
			return this.scheduler?.getJobName();
		}

		public void validate() {
			if (this.asyncJob == null) {
				// Job doesn't exist. Schedule a new one
				this.scheduler?.scheduleNewJob();
			} else {
				// Job exists; ensure that it matches the configured interval
				Integer interval = this.jobSettings?.Interval__c?.intValue();
				if (this.asyncJob?.CronTrigger?.NextFireTime > DateTime.now()?.addMinutes(interval)) {
					// Out of range of the current interval. Abort it and schedule a new one
					AsyncActionScheduledJobUtils.abortJobs(this.asyncJob);
					this.scheduler?.scheduleNewJob();
				}
			}
		}
	}
}
