@SuppressWarnings('PMD.ApexDoc')
public without sharing class AsyncActionSchedulable implements System.Schedulable {
	// **** STATIC **** //
	public static final String HOURLY = '0 0 * * * ?';
	public static final String JOB_PREFIX = AsyncActionSchedulable.class?.getName() + ': ';
	private static final Integer DEFAULT_INTERVAL = 60;

	// **** MEMBER **** //
	private AsyncActionScheduledJob__mdt jobSettings;

	public AsyncActionSchedulable(AsyncActionScheduledJob__mdt jobSettings) {
		this.jobSettings = jobSettings;
	}

	public void execute(System.SchedulableContext context) {
		this.getUpdatedJobSettings();
		if (this.jobSettings != null) {
			this.doScheduledActions();
			this.reschedule(context?.getTriggerId());
		}
		// Once completed, ensure other scheduled jobs match the configuration
		new AsyncActionScheduleEnforcer().enforce();
		AsyncActionLogger.save();
	}

	public String getJobName() {
		return JOB_PREFIX + this.jobSettings?.DeveloperName;
	}

	public Id scheduleNewJob() {
		// If the Scheduled Job is disabled, do not reschedule
		if (this.jobSettings?.Enabled__c == true) {
			String jobName = this.getJobName();
			String cronExp = this.getCronExpression();
			Id jobId = System.schedule(jobName, cronExp, this);
			String msg = 'Scheduled new job: ' + jobId + '|' + jobName + '|' + cronExp;
			AsyncActionLogger.log(System.LoggingLevel.FINEST, msg);
			return jobId;
		} else {
			String msg = this.jobSettings?.DeveloperName + ' is not enabled';
			AsyncActionLogger.log(System.LoggingLevel.FINEST, msg);
			return null;
		}
	}

	private void doScheduledActions() {
		List<AsyncActionScheduledJobItem__mdt> items = this.getActiveItems();
		if (this.jobSettings?.Enabled__c == true && items?.isEmpty() == false) {
			String actions = this.getCommaSeparatedActions(items);
			AsyncActionStart__e event = new AsyncActionStart__e(Actions__c = actions);
			EventBus.publish(event);
		}
	}

	private List<AsyncActionScheduledJobItem__mdt> getActiveItems() {
		List<AsyncActionScheduledJobItem__mdt> activeItems = new List<AsyncActionScheduledJobItem__mdt>();
		for (AsyncActionScheduledJobItem__mdt item : AsyncActionScheduledJobItemService.getJobItems(this.jobSettings)) {
			if (item?.Enabled__c == true) {
				activeItems?.add(item);
			}
		}
		return activeItems;
	}

	private String getCommaSeparatedActions(List<AsyncActionScheduledJobItem__mdt> items) {
		Set<String> actionSet = new Set<String>();
		for (AsyncActionScheduledJobItem__mdt item : items) {
			String processorClass = item?.AsyncActionProcessor__r?.Processor__c;
			actionSet?.add(processorClass);
		}
		return String.join(actionSet, ',');
	}

	private String getCronExpression() {
		// Generate a Cron Expression based on the current scheduled job's configuration
		if (this.jobSettings?.Type__c == 'Custom') {
			// Use the provided Cron Expression
			return this.jobSettings?.CronExpression__c ?? HOURLY;
		} else if (this.jobSettings?.Type__c == 'Semi-Hourly') {
			// Run the job every X minutes, starting X minutes from now
			Integer interval = this.getInterval();
			return new Cron(HOURLY)?.minutesFromNow(interval)?.expression();
		} else {
			// Default to Hourly
			return HOURLY;
		}
	}

	private Integer getInterval() {
		return this.jobSettings?.Interval__c?.intValue() ?? DEFAULT_INTERVAL;
	}

	private void getUpdatedJobSettings() {
		// Get the latest values of the job settings record, in case it changed since the last scheduled run
		String jobName = this.jobSettings?.DeveloperName;
		this.jobSettings = AsyncActionScheduledJobService.get(jobName);
	}

	private Id reschedule(Id currentJobId) {
		// Deletes the current job, then schedules a new one for the defined interval
		List<AsyncApexJob> currentJobs = [
			SELECT CronTriggerId, CronTrigger.CronJobDetail.Name
			FROM AsyncApexJob
			WHERE CronTriggerId = :currentJobId
			WITH SYSTEM_MODE
		];
		AsyncActionScheduledJobUtils.abortJobs(currentJobs);
		return this.scheduleNewJob();
	}

	// **** INNER **** //
	private class Cron {
		private String seconds;
		private String minutes;
		private String hours;
		private String dayOfMonth;
		private String month;
		private String dayOfWeek;

		private Cron(String exp) {
			// Expsting exp to be a valid Cron string
			List<String> parts = exp?.split(' ');
			this.seconds = parts[0];
			this.minutes = parts[1];
			this.hours = parts[2];
			this.dayOfMonth = parts[3];
			this.month = parts[4];
			this.dayOfWeek = parts[5];
		}

		private String expression() {
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

		private Cron minutesFromNow(Integer minsInFuture) {
			// Alter the minutes value to be X minutes from now
			Integer newMins = DateTime.now().addMinutes(minsInFuture).minute();
			this.minutes = String.valueOf(newMins);
			return this;
		}
	}
}
