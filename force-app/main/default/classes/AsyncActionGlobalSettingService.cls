public abstract class AsyncActionGlobalSettingService {
	@TestVisible
	static AsyncActionGlobalSetting__mdt settings;

	public static AsyncActionGlobalSetting__mdt getSettings() {
		settings = settings ?? AsyncActionGlobalSettingService.retrieveFirstFromOrg();
		return settings;
	}

	static AsyncActionGlobalSetting__mdt retrieveFirstFromOrg() {
		// This class expects that there will only ever be at most one settings record
		List<AsyncActionGlobalSetting__mdt> allSettings = AsyncActionGlobalSetting__mdt.getAll()?.values();
		return allSettings?.isEmpty() == false ? allSettings[0] : null;
	}
}
