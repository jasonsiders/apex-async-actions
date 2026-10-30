/**
 * @description Schedulable class that runs AsyncAction jobs on a regularly scheduled cadence.
 * Schedule configuration is defined by the AsyncActionScheduledJob__mdt custom metadata type.
 */
public without sharing class AsyncActionSchedulable implements System.Schedulable {
	// **** MEMBER **** //
	private AsyncActionScheduledJob__mdt jobSettings;

	/**
	 * @description Constructs an AsyncActionSchedulable with the specified job settings.
	 * @param jobSettings The scheduled job configuration metadata
	 */
	public AsyncActionSchedulable(AsyncActionScheduledJob__mdt jobSettings) {
		this.jobSettings = jobSettings;
	}

	/**
	 * @description Executes the scheduled job, processing active job items and rescheduling as needed.
	 * @param context The schedulable execution context
	 */
	public void execute(System.SchedulableContext context) {
		// On a scheduled cadence, this class will launch all of its job items
		this.getUpdatedJobSettings();
		if (this.jobSettings != null) {
			this.doScheduledActions();
			this.reschedule(context?.getTriggerId());
		}
		// Once completed, ensure all scheduled jobs match the currently defined configuration in cmdt
		new AsyncActions.EventPublisher()?.enforceScheduledJobs();
		AsyncActionLogger.save();
	}

	private void doScheduledActions() {
		List<AsyncActionScheduledJobItem__mdt> items = this.getActiveItems();
		if (this.jobSettings?.Enabled__c == true) {
			Set<String> processorNames = this.getProcessorNames(items);
			new AsyncActions.EventPublisher()?.start(processorNames);
		}
	}

	private List<AsyncActionScheduledJobItem__mdt> getActiveItems() {
		List<AsyncActionScheduledJobItem__mdt> activeItems = new List<AsyncActionScheduledJobItem__mdt>{};
		for (AsyncActionScheduledJobItem__mdt item : AsyncActionScheduledJobItemService.getJobItems(this.jobSettings)) {
			if (item?.Enabled__c == true) {
				activeItems?.add(item);
			}
		}
		return activeItems;
	}

	/**
	 * @description Collects names, since AsyncActionStart__e identifies processors by DeveloperName
	 * @param items The active job items to start
	 * @return DeveloperNames of the items' processors
	 */
	private Set<String> getProcessorNames(List<AsyncActionScheduledJobItem__mdt> items) {
		Set<String> processorNames = new Set<String>{};
		for (AsyncActionScheduledJobItem__mdt item : items) {
			String processorName = item?.AsyncActionProcessor__r?.DeveloperName;
			processorNames?.add(processorName);
		}
		return processorNames;
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
