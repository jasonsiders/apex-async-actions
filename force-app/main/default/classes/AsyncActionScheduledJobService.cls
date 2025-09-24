/**
 * @description Service class for retrieving AsyncActionScheduledJob__mdt objects from the database.
 * The settings property serves as a seam to inject test records in @IsTest context,
 * since custom metadata types cannot be manipulated via traditional DML.
 * See the AsyncActionTestUtils class methods to easily inject settings for your apex tests.
 */
public abstract class AsyncActionScheduledJobService {
	@TestVisible
	static Map<String, AsyncActionScheduledJob__mdt> settings;
	@TestVisible
	static Boolean useRealData = (Test.isRunningTest() == false);

	/**
	 * @description Returns a map of all AsyncActionScheduledJob__mdt records.
	 * @return Map of AsyncActionScheduledJob__mdt records keyed by DeveloperName
	 */
	public static Map<String, AsyncActionScheduledJob__mdt> getAll() {
		AsyncActionScheduledJobService.retrieveSettings();
		return AsyncActionScheduledJobService.settings;
	}

	/**
	 * @description Returns a specific AsyncActionScheduledJob__mdt record by its DeveloperName.
	 * @param developerName The DeveloperName of the scheduled job to retrieve
	 * @return AsyncActionScheduledJob__mdt record or null if not found
	 */
	public static AsyncActionScheduledJob__mdt get(String developerName) {
		AsyncActionScheduledJobService.retrieveSettings();
		return settings?.get(developerName);
	}

	static void retrieveSettings() {
		// If settings have not already been fetched, instantiate or fetch from org, depending on context
		if (settings == null && useRealData == true) {
			settings = AsyncActionScheduledJob__mdt.getAll();
		} else if (settings == null) {
			settings = new Map<String, AsyncActionScheduledJob__mdt>{};
		}
	}
}
