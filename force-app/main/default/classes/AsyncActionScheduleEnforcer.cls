/**
 * @description Class responsible for ensuring that the Scheduled Jobs queue
 * is in alignment with the current AsyncActionScheduledJob__mdt records at all times.
 * Validates existing jobs and schedules new ones as needed.
 */
public without sharing class AsyncActionScheduleEnforcer {
	/** @description Map of job names to their corresponding job wrapper instances **/
	private Map<String, JobWrapper> jobs;
	/** @description CronTriggers with no enabled setting, which enforce() aborts **/
	private List<CronTrigger> orphanedJobs;

	// **** PUBLIC **** //

	/** @description Constructor that initializes the job wrapper map **/
	public AsyncActionScheduleEnforcer() {
		this.jobs = new Map<String, JobWrapper>{};
		this.orphanedJobs = new List<CronTrigger>{};
	}

	/** @description Ensures that CronTriggers created by the framework match the current AsyncActionScheduledJob__mdt configuration **/
	public void enforce() {
		this.registerJobs();
		AsyncActionScheduledJobUtils.abortJobs(this.orphanedJobs);
		this.validateJobs();
	}

	/**
	 * @description Read-only, so callers can skip enforce() when it would change nothing
	 * @return Whether any job is missing, misconfigured, or disabled
	 */
	public Boolean needsEnforcement() {
		this.registerJobs();
		Boolean hasInvalidJobs = this.hasInvalidJobs();
		return hasInvalidJobs || this.orphanedJobs?.isEmpty() == false;
	}

	// **** PRIVATE **** //

	/** @description Matches each pending CronTrigger to its enabled setting **/
	private void registerJobs() {
		this.retrieveJobSettings();
		List<CronTrigger> cronTriggers = this.getPendingJobs();
		this.registerExistingJobs(cronTriggers);
	}

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
	 * @description Maps each CronTrigger to its wrapper, or to orphanedJobs if it has no enabled setting
	 * @param cronTriggers List of existing CronTrigger records to register
	 */
	private void registerExistingJobs(List<CronTrigger> cronTriggers) {
		for (CronTrigger ct : cronTriggers) {
			String jobName = ct?.CronJobDetail?.Name;
			JobWrapper wrapper = this.jobs?.get(jobName)?.addCronTrigger(ct);
			if (wrapper == null) {
				this.orphanedJobs?.add(ct);
			}
		}
	}

	/** @description Validates each wrapper, scheduling or rescheduling jobs as needed **/
	private void validateJobs() {
		for (JobWrapper job : this.jobs?.values()) {
			job?.validate();
		}
	}

	/**
	 * @description Read-only counterpart to validateJobs()
	 * @return Whether any enabled job is missing or misconfigured
	 */
	private Boolean hasInvalidJobs() {
		Boolean hasInvalidJobs = false;
		for (JobWrapper job : this.jobs?.values()) {
			hasInvalidJobs = hasInvalidJobs || job?.isValid() == false;
		}
		return hasInvalidJobs;
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
			if (this.cronTrigger == null) {
				AsyncActionScheduledJobUtils.scheduleNewJob(this.jobSettings);
			} else if (this.isValid() == false) {
				AsyncActionScheduledJobUtils.abortJobs(this.cronTrigger);
				AsyncActionScheduledJobUtils.scheduleNewJob(this.jobSettings);
			}
		}

		/**
		 * @description Read-only, so callers can check whether validate() would change anything
		 * @return Whether the job is scheduled and matches its settings
		 */
		public Boolean isValid() {
			String type = this.jobSettings?.Type__c;
			Boolean isValid = this.cronTrigger != null;
			if (type == 'Custom') {
				isValid = isValid && this.isValidCustomJob();
			} else if (type == 'Hourly') {
				isValid = isValid && this.isValidHourlyJob();
			} else if (type == 'Semi-Hourly') {
				isValid = isValid && this.isValidSemiHourlyJob();
			}
			return isValid;
		}

		/**
		 * @description Checks the cron expression against the configured value
		 * @return Whether they match
		 */
		private Boolean isValidCustomJob() {
			return this.cronTrigger?.CronExpression == this.jobSettings?.CronExpression__c;
		}

		/**
		 * @description Checks the cron expression against the standard hourly expression
		 * @return Whether they match
		 */
		private Boolean isValidHourlyJob() {
			return this.cronTrigger?.CronExpression == AsyncActionScheduledJobUtils.HOURLY_CRON_EXP;
		}

		/**
		 * @description Checks the next fire time, since semi-hourly jobs reschedule themselves after each run
		 * @return Whether the job fires within the configured interval
		 */
		private Boolean isValidSemiHourlyJob() {
			Integer interval = this.jobSettings?.Interval__c?.intValue();
			DateTime shouldFireBefore = DateTime.now()?.addMinutes(interval);
			DateTime nextFireTime = this.cronTrigger?.NextFireTime;
			Boolean firesTooLate = shouldFireBefore < nextFireTime;
			return firesTooLate == false;
		}
	}
}
