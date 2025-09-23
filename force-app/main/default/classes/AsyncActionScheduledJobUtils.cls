public without sharing abstract class AsyncActionScheduledJobUtils {
	/**
	 * This class provides common utility methods used by the framework's scheduled jobs mechanism
	 **/
	public static final String HOURLY_CRON_EXP = '0 0 * * * ?';
	public static final String SCHEDULED_JOB_PREFIX = AsyncActionSchedulable.class?.getName() + ': ';
	private static final Integer DEFAULT_INTERVAL = 60;

	public static void abortJobs(List<AsyncApexJob> jobs) {
		// Aborts the given AsyncApexJobs
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

	public static void abortJobs(AsyncApexJob job) {
		AsyncActionScheduledJobUtils.abortJobs(new List<AsyncApexJob>{ job });
	}

	public static String getJobName(AsyncActionScheduledJob__mdt jobSettings) {
		// Returns the unique name of the current scheduled job
		return SCHEDULED_JOB_PREFIX + jobSettings?.DeveloperName;
	}

	public static Id scheduleNewJob(AsyncActionScheduledJob__mdt jobSettings) {
		// Schedules a new instance of the current job, unless it's disabled
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

	private static String getCronExpression(AsyncActionScheduledJob__mdt jobSettings) {
		// Generate a Cron Expression based on the current scheduled job's configuration
		if (jobSettings?.Type__c == 'Custom') {
			// Use the provided Cron Expression
			return jobSettings?.CronExpression__c ?? HOURLY_CRON_EXP;
		} else if (jobSettings?.Type__c == 'Semi-Hourly') {
			// Run the job every X minutes, starting X minutes from now
			Integer interval = jobSettings?.Interval__c?.intValue() ?? 60;
			return new Cron(HOURLY_CRON_EXP)?.minutesFromNow(interval)?.expression();
		} else {
			// Default to Hourly
			return HOURLY_CRON_EXP;
		}
	}

	// **** INNER **** //
	private class Cron {
		/**
		 * This class is used internally to manipulate cron expressions
		 * Callers can use the `minutesFromNow` method
		 * to add X number of minutes to an existing cron expression
		 **/
		private String seconds;
		private String minutes;
		private String hours;
		private String dayOfMonth;
		private String month;
		private String dayOfWeek;

		private Cron(String exp) {
			// Expsting exp to be a valid Cron string
			List<String> parts = exp?.split(' ');
			this.seconds = parts?.get(0);
			this.minutes = parts?.get(1);
			this.hours = parts?.get(2);
			this.dayOfMonth = parts?.get(3);
			this.month = parts?.get(4);
			this.dayOfWeek = parts?.get(5);
		}

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

		public Cron minutesFromNow(Integer minsInFuture) {
			// Alter the minutes value to be X minutes from now
			Integer newMins = DateTime.now().addMinutes(minsInFuture).minute();
			this.minutes = String.valueOf(newMins);
			return this;
		}
	}
}
