public without sharing class AsyncActionSchedulable implements System.Schedulable {
	/**
	 * This class runs AsyncAction jobs on a regularly scheduled cadence,
	 * defined by the `AsyncActionScheduledJob__mdt` custom metadata type
	 **/
	// **** MEMBER **** //
	private AsyncActionScheduledJob__mdt jobSettings;

	public AsyncActionSchedulable(AsyncActionScheduledJob__mdt jobSettings) {
		this.jobSettings = jobSettings;
	}

	public void execute(System.SchedulableContext context) {
		// On a scheduled cadence, this class will launch all of its job items
		this.getUpdatedJobSettings();
		if (this.jobSettings != null) {
			this.doScheduledActions();
			this.reschedule(context?.getTriggerId());
		}
		// Once completed, ensure all scheduled jobs match the currently defined configuration in cmdt
		new AsyncActionScheduleEnforcer().enforce();
		AsyncActionLogger.save();
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
			String actionName = item?.AsyncActionProcessor__r?.DeveloperName;
			actionSet?.add(actionName);
		}
		return String.join(actionSet, ',');
	}

	private List<AsyncApexJob> getCurrentJobDetails(Id currentJobId) {
		return [
			SELECT CronTriggerId, CronTrigger.CronJobDetail.Name
			FROM AsyncApexJob
			WHERE CronTriggerId = :currentJobId
			WITH SYSTEM_MODE
		];
	}

	private void getUpdatedJobSettings() {
		// Get the latest values of the job settings record, in case it changed since the last scheduled run
		String jobName = this.jobSettings?.DeveloperName;
		this.jobSettings = AsyncActionScheduledJobService.get(jobName);
	}

	private Id reschedule(Id currentJobId) {
		// Deletes the current job, then schedules a new one for the defined interval
		List<AsyncApexJob> currentJobs = this.getCurrentJobDetails(currentJobId);
		AsyncActionScheduledJobUtils.abortJobs(currentJobs);
		return AsyncActionScheduledJobUtils.scheduleNewJob(this.jobSettings);
	}
}
