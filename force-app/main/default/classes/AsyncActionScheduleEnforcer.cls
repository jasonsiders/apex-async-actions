@SuppressWarnings('PMD.ApexDoc')
public without sharing class AsyncActionScheduleEnforcer {
	// This class can be called at any time to ensure that the Scheduled Jobs queue
	// is in alignment with the current AsyncActionScheduledJob__mdt records
	private Map<String, JobWrapper> jobs;

	public AsyncActionScheduleEnforcer() {
		this.jobs = new Map<String, JobWrapper>();
	}

	public void enforce() {
		// Ensures that AsyncApexJobs created by the framework matches the current AsyncActionScheduledJob__mdt configuration
		this.retrieveJobSettings();
		List<AsyncApexJob> asyncJobs = this.getPendingJobs();
		this.registerExistingJobs(asyncJobs);
		this.validateJobs();
	}

	private List<AsyncApexJob> getPendingJobs() {
		return [
			SELECT
				Id,
				ApexClass.Name,
				CreatedDate,
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
			ORDER BY CronTrigger.NextFireTime ASC
		];
	}

	private void registerExistingJobs(List<AsyncApexJob> asyncJobs) {
		// Add each provided AsyncApexJob to its corresponding JobWrapper
		for (AsyncApexJob asyncJob : asyncJobs) {
			String jobName = asyncJob?.CronTrigger?.CronJobDetail?.Name;
			JobWrapper wrapper = this.jobs?.get(jobName)?.addAsyncJob(asyncJob);
			if (wrapper == null) {
				// A corresponding job does not exist, or is not active. Abort it
				AsyncActionScheduledJobUtils.abortJobs(asyncJob);
			}
		}
	}

	private void validateJobs() {
		// Iterate through the jobs and ensure that they are configured for the correct intervals
		for (JobWrapper job : this.jobs?.values()) {
			job?.validate();
		}
	}

	private void retrieveJobSettings() {
		// Retrieve scheduled job settings, create a wrapper for each, and map by their job name
		for (AsyncActionScheduledJob__mdt jobSetting : AsyncActionScheduledJobService.getAll()?.values()) {
			if (jobSetting?.Enabled__c == true) {
				JobWrapper wrapper = new JobWrapper(jobSetting);
				String jobName = wrapper?.getJobName();
				this.jobs?.put(jobName, wrapper);
			}
		}
	}

	// **** INNER **** //
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
			try {
				if (this.asyncJob == null) {
					// Job doesn't exist. Schedule a new one
					this.scheduler?.scheduleNewJob();
				} else if (this.jobSettings?.Type__c == 'Custom') {
					// Job exists; its cron expression should match
					this.validateCustomJob();
				} else if (this.jobSettings?.Type__c == 'Hourly') {
					// Job exists; should be set up to fire hourly
					this.validateHourlyJob();
				} else if (this.jobSettings?.Type__c == 'Semi-Hourly') {
					// Job exists; should fire every X minutes, according to the interval
					this.validateSemiHourlyJob();
				}
			} catch (AsyncActionScheduleEnforcer.ValidationException error) {
				// Abort the current job, and schedule a new one
				AsyncActionScheduledJobUtils.abortJobs(this.asyncJob);
				this.scheduler?.scheduleNewJob();
			}
		}

		private void validateCustomJob() {
			// Ensure the current job's cron expression matches the custom configuration
			if (this.asyncJob?.CronTrigger?.CronExpression != this.jobSettings?.CronExpression__c) {
				// This cron expression should always match
				throw new AsyncActionScheduleEnforcer.ValidationException();
			}
		}

		private void validateHourlyJob() {
			// Ensure that the current job's cron expression is hourly
			if (this.asyncJob?.CronTrigger?.CronExpression != AsyncActionSchedulable.HOURLY) {
				throw new AsyncActionScheduleEnforcer.ValidationException();
			}
		}

		private void validateSemiHourlyJob() {
			// Ensure that the current job matches the configured interval
			Integer interval = this.jobSettings?.Interval__c?.intValue();
			DateTime shouldFireBefore = DateTime.now()?.addMinutes(interval);
			DateTime nextFireTime = this.asyncJob?.CronTrigger?.NextFireTime;
			if (shouldFireBefore < nextFireTime) {
				// Out of range of the current interval!
				throw new AsyncActionScheduleEnforcer.ValidationException();
			}
		}
	}

	private class ValidationException extends Exception {
	}
}
