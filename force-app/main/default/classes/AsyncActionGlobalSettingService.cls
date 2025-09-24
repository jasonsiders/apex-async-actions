/**
 * @description Service class for retrieving AsyncActionGlobalSetting__mdt objects from the database.
 * The settings property serves as a seam to inject test records in @IsTest context,
 * since custom metadata types cannot be manipulated via traditional DML.
 * See the AsyncActionTestUtils class methods to easily inject settings for your apex tests.
 */
public abstract class AsyncActionGlobalSettingService {
	@TestVisible
	static AsyncActionGlobalSetting__mdt settings;

	/**
	 * @description Retrieves the global settings record for the AsyncAction framework.
	 * @return AsyncActionGlobalSetting__mdt record or null if none configured
	 */
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
