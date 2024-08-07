public without sharing abstract class AsyncActionScheduledJobUtils {
	static AsyncActionLogger.Adapter LOGGER = AsyncActionLogger.init();

	public static void abortJobs(List<AsyncApexJob> jobs) {
		for (AsyncApexJob job : jobs) {
			String jobName = job?.CronTrigger?.CronJobDetail?.Name;
			Id jobId = job?.CronTriggerId;
			if (jobId != null) {
				String msg = 'Aborting job: ' + jobName + ' [' + jobId + ']';
				LOGGER?.log(System.LoggingLevel.FINEST, AsyncActionScheduledJobUtils.class, null, msg);
				System.abortJob(jobId);
			}
		}
	}

	public static void abortJobs(AsyncApexJob job) {
		AsyncActionScheduledJobUtils.abortJobs(new List<AsyncApexJob>{ job });
	}
}
