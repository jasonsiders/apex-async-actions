@SuppressWarnings('PMD.ApexDoc')
public abstract class AsyncActionScheduledJobService {
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
			settings = new Map<String, AsyncActionScheduledJob__mdt>();
		}
	}
}
