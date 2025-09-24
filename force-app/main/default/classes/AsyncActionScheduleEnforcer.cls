/**
 * @description Class responsible for ensuring that the Scheduled Jobs queue
 * is in alignment with the current AsyncActionScheduledJob__mdt records at all times.
 * Validates existing jobs and schedules new ones as needed.
 */
public without sharing class AsyncActionScheduleEnforcer {
	/**
	 * @description Map of job names to their corresponding job wrapper instances
	 */
	private Map<String, JobWrapper> jobs;

	/**
	 * @description Constructor that initializes the job wrapper map.
	 */
	public AsyncActionScheduleEnforcer() {
		this.jobs = new Map<String, JobWrapper>{};
	}

	/**
	 * @description Ensures that AsyncApexJobs created by the framework match the current AsyncActionScheduledJob__mdt configuration.
	 */
	public void enforce() {
		// Ensures that AsyncApexJobs created by the framework matches the current AsyncActionScheduledJob__mdt configuration
		this.retrieveJobSettings();
		List<AsyncApexJob> asyncJobs = this.getPendingJobs();
		this.registerExistingJobs(asyncJobs);
		this.validateJobs();
	}

	/**
	 * @description Retrieves pending AsyncApexJobs for AsyncActionSchedulable
	 * @return List of pending AsyncApexJob records
	 */
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

	/**
	 * @description Registers existing AsyncApexJobs with their corresponding job wrappers
	 * @param asyncJobs List of existing AsyncApexJob records to register
	 */
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

	/**
	 * @description Validates all registered jobs to ensure they match their configuration
	 */
	private void validateJobs() {
		// Iterate through the jobs and ensure that they are configured for the correct intervals
		for (JobWrapper job : this.jobs?.values()) {
			job?.validate();
		}
	}

	/**
	 * @description Retrieves scheduled job settings and creates job wrappers for enabled jobs
	 */
	private void retrieveJobSettings() {
		// Retrieve scheduled job settings, create a wrapper for each, and map by their job name
		for (AsyncActionScheduledJob__mdt jobSetting : AsyncActionScheduledJobService.getAll()?.values()) {
			if (jobSetting?.Enabled__c == true) {
				JobWrapper wrapper = new JobWrapper(jobSetting);
				String jobName = AsyncActionScheduledJobUtils.getJobName(jobSetting);
				this.jobs?.put(jobName, wrapper);
			}
		}
	}

	// **** INNER **** //
	/**
	 * @description Wrapper class for managing AsyncApexJob and its corresponding settings
	 */
	private class JobWrapper {
		/**
		 * @description The AsyncApexJob instance associated with this wrapper
		 */
		AsyncApexJob asyncJob;

		/**
		 * @description The interval setting for this job
		 */
		Integer interval;

		/**
		 * @description The scheduled job configuration metadata
		 */
		AsyncActionScheduledJob__mdt jobSettings;

		/**
		 * @description Constructor for JobWrapper
		 * @param jobSettings The scheduled job configuration metadata
		 */
		public JobWrapper(AsyncActionScheduledJob__mdt jobSettings) {
			this.jobSettings = jobSettings;
			this.interval = jobSettings?.Interval__c?.intValue();
		}

		/**
		 * @description Associates an AsyncApexJob with this wrapper
		 * @param asyncJob The AsyncApexJob to associate
		 * @return This JobWrapper instance for method chaining
		 */
		public JobWrapper addAsyncJob(AsyncApexJob asyncJob) {
			this.asyncJob = asyncJob;
			return this;
		}

		/**
		 * @description Validates the job against its configuration and schedules/aborts as needed
		 */
		public void validate() {
			try {
				if (this.asyncJob == null) {
					// Job doesn't exist. Schedule a new one
					AsyncActionScheduledJobUtils.scheduleNewJob(this.jobSettings);
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
				AsyncActionScheduledJobUtils.scheduleNewJob(this.jobSettings);
			}
		}

		/**
		 * @description Validates that a custom job's cron expression matches the configuration
		 */
		private void validateCustomJob() {
			// Ensure the current job's cron expression matches the custom configuration
			if (this.asyncJob?.CronTrigger?.CronExpression != this.jobSettings?.CronExpression__c) {
				// This cron expression should always match
				throw new AsyncActionScheduleEnforcer.ValidationException();
			}
		}

		/**
		 * @description Validates that an hourly job has the correct cron expression
		 */
		private void validateHourlyJob() {
			// Ensure that the current job's cron expression is hourly
			if (this.asyncJob?.CronTrigger?.CronExpression != AsyncActionScheduledJobUtils.HOURLY_CRON_EXP) {
				throw new AsyncActionScheduleEnforcer.ValidationException();
			}
		}

		/**
		 * @description Validates that a semi-hourly job's next fire time is within the configured interval
		 */
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

	/**
	 * @description Exception thrown when job validation fails
	 */
	private class ValidationException extends Exception {
	}
}
