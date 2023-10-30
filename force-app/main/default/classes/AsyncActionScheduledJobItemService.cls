global abstract without sharing class AsyncActionScheduledJobItemService {
	@TestVisible
	static Map<String, List<AsyncActionScheduledJobItem__mdt>> jobItems = new Map<String, List<AsyncActionScheduledJobItem__mdt>>();

	global static List<AsyncActionScheduledJobItem__mdt> getJobItems(AsyncActionScheduledJob__mdt jobSettings) {
        // Retrieve all active AsyncActionScheduledJobItem__mdt records that match the scheduled job settings
		String jobName = jobSettings?.DeveloperName;
		if (jobItems?.containsKey(jobName) == false) {
			// Note: CMDT SOQL queries do not count against limits!
			List<AsyncActionScheduledJobItem__mdt> matching = [
				SELECT AsyncActionProcessor__r.DeveloperName, AsyncActionProcessor__r.ProcessorClass__c, ScheduledJob__r.DeveloperName
				FROM AsyncActionScheduledJobItem__mdt
				WHERE Enabled__c = TRUE AND ScheduledJob__r.DeveloperName = :jobName
			];
			jobItems?.put(jobName, matching);
		}
		return jobItems?.get(jobName);
	}
}
