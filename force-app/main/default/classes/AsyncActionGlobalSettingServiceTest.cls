@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class AsyncActionGlobalSettingServiceTest {
	@IsTest
	static void shouldRetrieveSettingsFromOrg() {
		List<AsyncActionGlobalSetting__mdt> orgSettings = AsyncActionGlobalSetting__mdt.getAll()?.values();

		Test.startTest();
		AsyncActionGlobalSetting__mdt settings = AsyncActionGlobalSettingService.getSettings();
		Test.stopTest();

		if (orgSettings?.isEmpty() == false) {
			Assert.areNotEqual(null, settings, 'Did not fetch settings from org');
		} else {
			Assert.areEqual(null, settings, 'No settings in org, but still returned a non-null value');
		}
	}

	@IsTest
	static void shouldInjectSettings() {
		AsyncActionGlobalSetting__mdt mockSettings = new AsyncActionGlobalSetting__mdt(DeveloperName = 'foo1234');
		AsyncActionGlobalSettingService.settings = mockSettings;

		Test.startTest();
		AsyncActionGlobalSetting__mdt settings = AsyncActionGlobalSettingService.getSettings();
		Test.stopTest();

		Assert.areEqual(mockSettings?.DeveloperName, settings?.DeveloperName, 'Did not use injected settings');
	}
}
