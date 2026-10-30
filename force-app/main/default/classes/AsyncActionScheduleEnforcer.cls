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
		List<CronTrigger> orphanedJobs = this.registerJobs();
		AsyncActionScheduledJobUtils.abortJobs(orphanedJobs);
		this.validateJobs();
	}

	/**
	 * @description Changes no scheduled jobs, so callers can skip enforce() when it would do nothing
	 * @return Whether any job is missing, misconfigured, or disabled
	 */
	public Boolean needsEnforcement() {
		List<CronTrigger> orphanedJobs = this.registerJobs();
		Boolean hasInvalidJobs = this.hasInvalidJobs();
		return hasInvalidJobs || orphanedJobs?.isEmpty() == false;
	}

	// **** PRIVATE **** //

	/**
	 * @description Matches each pending CronTrigger to its enabled setting
	 * @return The CronTriggers with no enabled setting
	 */
	private List<CronTrigger> registerJobs() {
		this.retrieveJobSettings();
		List<CronTrigger> cronTriggers = this.getPendingJobs();
		return this.registerExistingJobs(cronTriggers);
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
	 * @description Maps each CronTrigger to its wrapper
	 * @param cronTriggers List of existing CronTrigger records to register
	 * @return The CronTriggers with no enabled setting, which have no wrapper
	 */
	private List<CronTrigger> registerExistingJobs(List<CronTrigger> cronTriggers) {
		List<CronTrigger> orphanedJobs = new List<CronTrigger>{};
		for (CronTrigger ct : cronTriggers) {
			String jobName = ct?.CronJobDetail?.Name;
			JobWrapper wrapper = this.jobs?.get(jobName)?.addCronTrigger(ct);
			if (wrapper == null) {
				orphanedJobs?.add(ct);
			}
		}
		return orphanedJobs;
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

		/** @description The scheduled job configuration metadata **/
		AsyncActionScheduledJob__mdt jobSettings;

		/**
		 * @description Constructor for JobWrapper
		 * @param jobSettings The scheduled job configuration metadata
		 */
		public JobWrapper(AsyncActionScheduledJob__mdt jobSettings) {
			this.jobSettings = jobSettings;
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

		/** @description Reschedules a missing or misconfigured job; abortJobs() skips a missing one **/
		public void validate() {
			if (this.isValid() == false) {
				AsyncActionScheduledJobUtils.abortJobs(this.cronTrigger);
				AsyncActionScheduledJobUtils.scheduleNewJob(this.jobSettings);
			}
		}

		/**
		 * @description Read-only, so callers can check whether validate() would change anything
		 * @return Whether the job is scheduled and matches its settings
		 */
		public Boolean isValid() {
			Boolean isSemiHourly = this.jobSettings?.Type__c == 'Semi-Hourly';
			Boolean matchesSettings = isSemiHourly ? this.isValidSemiHourlyJob() : this.isValidCronExpression();
			return this.cronTrigger != null && matchesSettings;
		}

		/**
		 * @description Compares against the expression scheduleNewJob() uses, including its hourly fallback
		 * @return Whether they match
		 */
		private Boolean isValidCronExpression() {
			String expected = AsyncActionScheduledJobUtils.getCronExpression(this.jobSettings);
			return this.cronTrigger?.CronExpression == expected;
		}

		/**
		 * @description Checks the next fire time, since semi-hourly jobs reschedule themselves after each run
		 * @return Whether the job fires within the configured interval
		 */
		private Boolean isValidSemiHourlyJob() {
			Integer interval = AsyncActionScheduledJobUtils.getInterval(this.jobSettings);
			DateTime shouldFireBefore = DateTime.now()?.addMinutes(interval);
			DateTime nextFireTime = this.cronTrigger?.NextFireTime;
			Boolean firesTooLate = shouldFireBefore < nextFireTime;
			return firesTooLate == false;
		}
	}
}
