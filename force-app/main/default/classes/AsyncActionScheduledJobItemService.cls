@SuppressWarnings('PMD.ApexDoc')
public abstract without sharing class AsyncActionScheduledJobItemService {
	/**
	 * This class is used to retrieve AsyncActionScheduledJobItem__mdt objects from the database
	 * Its `jobItems` property serves as a seam to inject test records in @IsTest context,
	 * since custom metadata types cannot be manipulated via traditional dml.
	 * See the `AsyncActionTestUtils` class methods to easily inject settings for your apex tests.
	 **/
	@TestVisible
	static Map<String, List<AsyncActionScheduledJobItem__mdt>> jobItems = new Map<String, List<AsyncActionScheduledJobItem__mdt>>();
	@TestVisible
	static Boolean useRealData = (Test.isRunningTest() == false);

	public static List<AsyncActionScheduledJobItem__mdt> getJobItems(AsyncActionScheduledJob__mdt jobSettings) {
		// Retrieve all active AsyncActionScheduledJobItem__mdt records that match the scheduled job settings
		String jobName = jobSettings?.DeveloperName;
		if (jobItems?.containsKey(jobName) == false && useRealData == true) {
			// Note: CMDT SOQL queries do not count against limits, so this is safe
			List<AsyncActionScheduledJobItem__mdt> matching = [
				SELECT
					AsyncActionProcessor__r.DeveloperName,
					AsyncActionProcessor__r.Processor__c,
					Enabled__c,
					ScheduledJob__r.DeveloperName
				FROM AsyncActionScheduledJobItem__mdt
				WHERE Enabled__c = TRUE AND ScheduledJob__r.DeveloperName = :jobName
				WITH SYSTEM_MODE
			];
			jobItems?.put(jobName, matching);
		}
		return jobItems?.containsKey(jobName) ? jobItems?.get(jobName) : new List<AsyncActionScheduledJobItem__mdt>();
	}
}
