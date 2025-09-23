public abstract class AsyncActionScheduledJobService {
	/**
	 * This class is used to retrieve AsyncActionScheduledJob__mdt objects from the database
	 * Its `settings` property serves as a seam to inject test records in @IsTest context,
	 * since custom metadata types cannot be manipulated via traditional dml.
	 * See the `AsyncActionTestUtils` class methods to easily inject settings for your apex tests.
	 **/
	@TestVisible
	static Map<String, AsyncActionScheduledJob__mdt> settings;
	@TestVisible
	static Boolean useRealData = (Test.isRunningTest() == false);

	public static Map<String, AsyncActionScheduledJob__mdt> getAll() {
		AsyncActionScheduledJobService.retrieveSettings();
		return AsyncActionScheduledJobService.settings;
	}

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
