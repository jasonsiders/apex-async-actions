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

	/** @description Skips a job disabled since its last run, which reschedule() then removes */
	private void doScheduledActions() {
		if (this.jobSettings?.Enabled__c == true) {
			Set<String> processorNames = this.getActiveProcessorNames();
			new AsyncActions.EventPublisher()?.start(processorNames);
		}
	}

	/**
	 * @description Gets the processors run by the job's enabled items
	 * @return The processors' DeveloperNames
	 */
	private Set<String> getActiveProcessorNames() {
		Set<String> processorNames = new Set<String>{};
		for (AsyncActionScheduledJobItem__mdt item : AsyncActionScheduledJobItemService.getJobItems(this.jobSettings)) {
			if (item?.Enabled__c == true) {
				String processorName = item?.AsyncActionProcessor__r?.DeveloperName;
				processorNames?.add(processorName);
			}
		}
		return processorNames;
	}

	/**
	 * @description Looks up the job name too, which abortJobs() logs
	 * @param currentJobId The CronTrigger ID of the running job
	 * @return The running job's AsyncApexJob records
	 */
	private List<AsyncApexJob> getCurrentJobDetails(Id currentJobId) {
		return [
			SELECT CronTriggerId, CronTrigger.CronJobDetail.Name
			FROM AsyncApexJob
			WHERE CronTriggerId = :currentJobId
			WITH SYSTEM_MODE
		];
	}

	/** @description Refreshes the settings, since they may have changed since the job was scheduled **/
	private void getUpdatedJobSettings() {
		String jobName = this.jobSettings?.DeveloperName;
		this.jobSettings = AsyncActionScheduledJobService.get(jobName);
	}

	/**
	 * @description Aborts the running job first, since the new one reuses its name
	 * @param currentJobId The CronTrigger ID of the running job
	 * @return The new job's ID, or null if it wasn't scheduled
	 */
	private Id reschedule(Id currentJobId) {
		List<AsyncApexJob> currentJobs = this.getCurrentJobDetails(currentJobId);
		AsyncActionScheduledJobUtils.abortJobs(currentJobs);
		return AsyncActionScheduledJobUtils.scheduleNewJob(this.jobSettings);
	}
}
