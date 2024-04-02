public without sharing abstract class AsyncActionScheduledJobUtils {
    static Logger LOGGER = new Logger()?.setLoggedFrom(AsyncActionScheduledJobUtils.class);

    public static void abortJobs(List<AsyncApexJob> jobs) {
        for (AsyncApexJob job : jobs) {
			String jobName = job?.CronTrigger?.CronJobDetail?.Name;
			Id jobId = job?.CronTriggerId;
			if (jobId != null) {
				LOGGER?.finest('Aborting job: ' + jobName + ' [' + jobId + ']');
				System.abortJob(jobId);
			}
		}
    }

    public static void abortJobs(AsyncApexJob job) {
        AsyncActionScheduledJobUtils.abortJobs(new List<AsyncApexJob>{ job });
    }
}