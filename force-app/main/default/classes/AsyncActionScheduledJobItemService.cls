/**
 * @description Service class for retrieving AsyncActionScheduledJobItem__mdt objects from the database.
 * The jobItems property serves as a seam to inject test records in @IsTest context,
 * since custom metadata types cannot be manipulated via traditional DML.
 * See the AsyncActionTestUtils class methods to easily inject settings for your apex tests.
 */
public abstract without sharing class AsyncActionScheduledJobItemService {
	@TestVisible
	static Map<String, List<AsyncActionScheduledJobItem__mdt>> jobItems = new Map<String, List<AsyncActionScheduledJobItem__mdt>>{};
	@TestVisible
	static Boolean useRealData = (Test.isRunningTest() == false);

	/**
	 * @description Retrieves all active AsyncActionScheduledJobItem__mdt records that match the scheduled job settings.
	 * @param jobSettings The scheduled job settings to find related job items for
	 * @return List of AsyncActionScheduledJobItem__mdt records for the specified job
	 */
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
		return jobItems?.containsKey(jobName) ? jobItems?.get(jobName) : new List<AsyncActionScheduledJobItem__mdt>{};
	}
}
