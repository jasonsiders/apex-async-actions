@SuppressWarnings('PMD.ApexDoc')
public without sharing abstract class AsyncActionScheduledJobUtils {
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

	public static void abortJobs(AsyncApexJob job) {
		AsyncActionScheduledJobUtils.abortJobs(new List<AsyncApexJob>{ job });
	}
}
