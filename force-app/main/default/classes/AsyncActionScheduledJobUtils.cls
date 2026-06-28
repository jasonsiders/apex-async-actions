/**
 * @description Abstract utility class providing common methods used by the framework's scheduled jobs mechanism.
 * Contains utilities for job management, scheduling, and cron expression handling.
 */
public without sharing abstract class AsyncActionScheduledJobUtils {
	// **** CONSTANTS **** //

	/** @description Standard hourly cron expression; used as the default for hourly job types **/
	public static final String HOURLY_CRON_EXP = '0 0 * * * ?';

	/** @description Prefix applied to all scheduled job names to distinguish framework-owned jobs **/
	public static final String SCHEDULED_JOB_PREFIX = AsyncActionSchedulable.class?.getName() + ': ';

	/** @description Fallback interval in minutes when none is configured **/
	private static final Integer DEFAULT_INTERVAL = 60;

	// **** PUBLIC **** //

	/**
	 * @description Aborts the given CronTriggers.
	 * @param cronTriggers List of CronTrigger records to abort
	 */
	public static void abortJobs(List<CronTrigger> cronTriggers) {
		for (CronTrigger ct : cronTriggers) {
			String jobName = ct?.CronJobDetail?.Name;
			Id jobId = ct?.Id;
			if (jobId != null) {
				String msg = 'Aborting job: ' + jobName + ' [' + jobId + ']';
				AsyncActionLogger.log(System.LoggingLevel.FINEST, msg);
				System.abortJob(jobId);
			}
		}
	}

	/**
	 * @description Aborts a single CronTrigger.
	 * @param cronTrigger The CronTrigger record to abort
	 */
	public static void abortJobs(CronTrigger cronTrigger) {
		AsyncActionScheduledJobUtils.abortJobs(new List<CronTrigger>{ cronTrigger });
	}

	/**
	 * @description Aborts the given AsyncApexJobs.
	 * @param jobs List of AsyncApexJob records to abort
	 */
	public static void abortJobs(List<AsyncApexJob> jobs) {
		for (AsyncApexJob job : jobs) {
			String jobName = job?.CronTrigger?.CronJobDetail?.Name;
			Id jobId = job?.CronTriggerId;
			if (jobId != null) {
				String msg = 'Aborting job: ' + jobName + ' [' + jobId + ']';
				AsyncActionLogger.log(System.LoggingLevel.FINEST, msg);
				System.abortJob(jobId);
			}
		}
	}

	/**
	 * @description Aborts a single AsyncApexJob.
	 * @param job The AsyncApexJob record to abort
	 */
	public static void abortJobs(AsyncApexJob job) {
		AsyncActionScheduledJobUtils.abortJobs(new List<AsyncApexJob>{ job });
	}

	/**
	 * @description Returns the unique name of the scheduled job based on job settings.
	 * @param jobSettings The scheduled job configuration metadata
	 * @return The unique job name with prefix
	 */
	public static String getJobName(AsyncActionScheduledJob__mdt jobSettings) {
		return SCHEDULED_JOB_PREFIX + jobSettings?.DeveloperName;
	}

	/**
	 * @description Schedules a new instance of the job, unless it's disabled.
	 * @param jobSettings The scheduled job configuration metadata
	 * @return ID of the scheduled job, or null if the job is disabled
	 */
	public static Id scheduleNewJob(AsyncActionScheduledJob__mdt jobSettings) {
		if (jobSettings?.Enabled__c == true) {
			String jobName = AsyncActionScheduledJobUtils.getJobName(jobSettings);
			String cronExp = AsyncActionScheduledJobUtils.getCronExpression(jobSettings);
			System.Schedulable job = new AsyncActionSchedulable(jobSettings);
			Id jobId = System.schedule(jobName, cronExp, job);
			String msg = 'Scheduled new job: ' + jobId + '|' + jobName + '|' + cronExp;
			AsyncActionLogger.log(System.LoggingLevel.FINEST, msg);
			return jobId;
		} else {
			String msg = jobSettings?.DeveloperName + ' is not enabled';
			AsyncActionLogger.log(System.LoggingLevel.FINEST, msg);
			return null;
		}
	}

	// **** PRIVATE **** //

	/**
	 * @description Derives the cron expression from the job type; defaults to hourly when type is unrecognized
	 * @param jobSettings The scheduled job configuration metadata
	 * @return The generated cron expression
	 */
	private static String getCronExpression(AsyncActionScheduledJob__mdt jobSettings) {
		if (jobSettings?.Type__c == 'Custom') {
			return jobSettings?.CronExpression__c ?? HOURLY_CRON_EXP;
		} else if (jobSettings?.Type__c == 'Semi-Hourly') {
			Integer interval = jobSettings?.Interval__c?.intValue() ?? DEFAULT_INTERVAL;
			return new Cron(HOURLY_CRON_EXP)?.minutesFromNow(interval)?.expression();
		} else {
			return HOURLY_CRON_EXP;
		}
	}

	// **** INNER **** //
	/**
	 * @description Internal class for manipulating cron expressions
	 */
	private class Cron {
		/** @description Seconds component **/
		private String seconds;

		/** @description Minutes component; mutated by minutesFromNow **/
		private String minutes;

		/** @description Hours component **/
		private String hours;

		/** @description Day-of-month component **/
		private String dayOfMonth;

		/** @description Month component **/
		private String month;

		/** @description Day-of-week component **/
		private String dayOfWeek;

		/**
		 * @description Parses a valid 6-part Salesforce cron expression into its components
		 * @param exp A valid Salesforce cron string (6 space-separated parts)
		 */
		private Cron(String exp) {
			List<String> parts = exp?.split(' ');
			this.seconds = parts?.get(0);
			this.minutes = parts?.get(1);
			this.hours = parts?.get(2);
			this.dayOfMonth = parts?.get(3);
			this.month = parts?.get(4);
			this.dayOfWeek = parts?.get(5);
		}

		/**
		 * @description Returns the cron expression as a string
		 * @return The formatted cron expression string
		 */
		public String expression() {
			List<String> parts = new List<String>{
				this.seconds,
				this.minutes,
				this.hours,
				this.dayOfMonth,
				this.month,
				this.dayOfWeek
			};
			return String.join(parts, ' ');
		}

		/**
		 * @description Shifts the minutes component to fire X minutes from now
		 * @param minsInFuture Number of minutes in the future
		 * @return This Cron instance for method chaining
		 */
		public Cron minutesFromNow(Integer minsInFuture) {
			Integer newMins = DateTime.now().addMinutes(minsInFuture).minute();
			this.minutes = String.valueOf(newMins);
			return this;
		}
	}
}
