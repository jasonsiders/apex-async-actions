global class AsyncActionSchedulable implements System.Schedulable {
	public static final String JOB_PREFIX = AsyncActionSchedulable.class?.getName() + ': ';
	static final Integer DEFAULT_INTERVAL = 60;
	static final String HOURLY = '0 0 * * * ?';
	static final Logger LOGGER = new Logger()
		?.setLoggedFrom(AsyncActionSchedulable.class)
		?.setSource(AsyncActionConstants.PACKAGE_NAME);
	AsyncActionScheduledJob__mdt jobSettings;

	global AsyncActionSchedulable(AsyncActionScheduledJob__mdt jobSettings) {
		this.jobSettings = jobSettings;
	}

	global void execute(System.SchedulableContext context) {
		this.getUpdatedJobSettings();
		if (this.jobSettings != null) {
			this.doScheduledActions();
			this.reschedule(context?.getTriggerId());
		}
		// Once completed, ensure other scheduled jobs match the configuration
		new AsyncActionScheduleEnforcer().enforce();
		LOGGER.publish();
	}

	public void abortJobs(List<AsyncApexJob> jobs) {
		for (AsyncApexJob job : jobs) {
			String jobName = job?.CronTrigger?.CronJobDetail?.Name;
			Id jobId = job?.CronTriggerId;
			if (jobId != null) {
				LOGGER?.finest('Aborting job: ' + jobName + ' [' + jobId + ']');
				System.abortJob(jobId);
			}
		}
	}

	public String getJobName() {
		return JOB_PREFIX + this.jobSettings?.Id;
	}

	public Id scheduleNewJob() {
		// If the Scheduled Job is disabled, do not reschedule
		if (this.jobSettings?.Enabled__c == true) {
			String jobName = this.getJobName();
			Integer interval = this.getInterval();
			String cronExp = new Cron(HOURLY)?.minutesFromNow(interval)?.expression();
			System.Schedulable newJob = new AsyncActionSchedulable(this.jobSettings);
			Id jobId = System.schedule(jobName, cronExp, newJob);
			LOGGER?.finest('Scheduled new job: ' + jobId + '|' + jobName + '|' + cronExp);
			return jobId;
		} else {
			LOGGER?.finest(this.jobSettings?.DeveloperName + ' is not enabled');
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
			String processorClass = item?.AsyncActionProcessor__r?.ProcessorClass__c;
			actionSet?.add(processorClass);
		}
		return String.join(actionSet, ',');
	}

	private Integer getInterval() {
		Integer interval = this.jobSettings?.Interval__c?.intValue();
		return (interval != null) ? interval : DEFAULT_INTERVAL;
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
		];
		this.abortJobs(currentJobs);
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
