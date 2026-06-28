/**
 * @description Class responsible for ensuring that the Scheduled Jobs queue
 * is in alignment with the current AsyncActionScheduledJob__mdt records at all times.
 * Validates existing jobs and schedules new ones as needed.
 */
public without sharing class AsyncActionScheduleEnforcer {
	/** @description Map of job names to their corresponding job wrapper instances **/
	private Map<String, JobWrapper> jobs;

	// **** PUBLIC **** //

	/** @description Constructor that initializes the job wrapper map **/
	public AsyncActionScheduleEnforcer() {
		this.jobs = new Map<String, JobWrapper>{};
	}

	/** @description Ensures that CronTriggers created by the framework match the current AsyncActionScheduledJob__mdt configuration **/
	public void enforce() {
		this.retrieveJobSettings();
		List<CronTrigger> cronTriggers = this.getPendingJobs();
		this.registerExistingJobs(cronTriggers);
		this.validateJobs();
	}

	// **** PRIVATE **** //

	/**
	 * @description Queries CronTrigger instead of AsyncApexJob — CronTriggers exist between firings even when no AsyncApexJob is in a queued state
	 * @return List of CronTrigger records
	 */
	private List<CronTrigger> getPendingJobs() {
		String jobNamePrefix = AsyncActionScheduledJobUtils.SCHEDULED_JOB_PREFIX + '%';
		return [
			SELECT Id, CronExpression, NextFireTime, CronJobDetail.Name
			FROM CronTrigger
			WHERE CronJobDetail.Name LIKE :jobNamePrefix AND State NOT IN ('DELETED', 'COMPLETE', 'ERROR')
			WITH SYSTEM_MODE
			ORDER BY NextFireTime ASC
		];
	}

	/**
	 * @description Maps each CronTrigger to its wrapper; aborts any that have no matching enabled setting
	 * @param cronTriggers List of existing CronTrigger records to register
	 */
	private void registerExistingJobs(List<CronTrigger> cronTriggers) {
		for (CronTrigger ct : cronTriggers) {
			String jobName = ct?.CronJobDetail?.Name;
			JobWrapper wrapper = this.jobs?.get(jobName)?.addCronTrigger(ct);
			if (wrapper == null) {
				AsyncActionScheduledJobUtils.abortJobs(ct);
			}
		}
	}

	/** @description Validates each wrapper, scheduling or rescheduling jobs as needed **/
	private void validateJobs() {
		for (JobWrapper job : this.jobs?.values()) {
			job?.validate();
		}
	}

	/** @description Builds wrappers for all enabled scheduled job settings **/
	private void retrieveJobSettings() {
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
	 * @description Wrapper class for managing a CronTrigger and its corresponding settings
	 */
	private class JobWrapper {
		/** @description The CronTrigger instance associated with this wrapper **/
		CronTrigger cronTrigger;

		/** @description Configured interval in minutes; used to assess whether the current NextFireTime is within range **/
		Integer interval;

		/** @description The scheduled job configuration metadata **/
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
		 * @description Associates a CronTrigger with this wrapper
		 * @param cronTrigger The CronTrigger to associate
		 * @return This JobWrapper instance for method chaining
		 */
		public JobWrapper addCronTrigger(CronTrigger cronTrigger) {
			this.cronTrigger = cronTrigger;
			return this;
		}

		/** @description Schedules a new job if none exists, or validates and reschedules the existing one if misconfigured **/
		public void validate() {
			try {
				if (this.cronTrigger == null) {
					AsyncActionScheduledJobUtils.scheduleNewJob(this.jobSettings);
				} else if (this.jobSettings?.Type__c == 'Custom') {
					this.validateCustomJob();
				} else if (this.jobSettings?.Type__c == 'Hourly') {
					this.validateHourlyJob();
				} else if (this.jobSettings?.Type__c == 'Semi-Hourly') {
					this.validateSemiHourlyJob();
				}
			} catch (AsyncActionScheduleEnforcer.ValidationException error) {
				AsyncActionScheduledJobUtils.abortJobs(this.cronTrigger);
				AsyncActionScheduledJobUtils.scheduleNewJob(this.jobSettings);
			}
		}

		/** @description Throws if the existing cron expression no longer matches the configured value **/
		private void validateCustomJob() {
			if (this.cronTrigger?.CronExpression != this.jobSettings?.CronExpression__c) {
				throw new AsyncActionScheduleEnforcer.ValidationException();
			}
		}

		/** @description Throws if the existing cron expression is not the standard hourly expression **/
		private void validateHourlyJob() {
			if (this.cronTrigger?.CronExpression != AsyncActionScheduledJobUtils.HOURLY_CRON_EXP) {
				throw new AsyncActionScheduleEnforcer.ValidationException();
			}
		}

		/** @description Throws if the next fire time is further out than the configured interval allows **/
		private void validateSemiHourlyJob() {
			Integer interval = this.jobSettings?.Interval__c?.intValue();
			DateTime shouldFireBefore = DateTime.now()?.addMinutes(interval);
			DateTime nextFireTime = this.cronTrigger?.NextFireTime;
			if (shouldFireBefore < nextFireTime) {
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
