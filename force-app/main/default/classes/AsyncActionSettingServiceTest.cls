@IsTest 
private class AsyncActionSettingServiceTest {
    @IsTest 
    static void shouldRetrieveSettingsFromOrg() {
        final String name = 'Default';

        Test.startTest();
        AsyncActionSetting__mdt settings = AsyncActionSettingService.getSettings(); 
        Test.stopTest();

        if (AsyncActionSetting__mdt.getAll()?.containsKey(name) == true) {
            Assert.isNotNull(settings, 'Settings in org, but returned null');
        } else {
            Assert.isNull(settings, 'No settings in org, but returned something'); 
        }
    }

    @IsTest 
    static void shouldRetrieveInjectedSettings() {
        AsyncActionSetting__mdt mockSettings = new AsyncActionSetting__mdt(DeveloperName = 'Testing_123');
        AsyncActionSettingService.settings = mockSettings;

        Test.startTest();
        AsyncActionSetting__mdt settings = AsyncActionSettingService.getSettings();
        Test.stopTest();

        Assert.areEqual(mockSettings?.DeveloperName, settings?.DeveloperName, 'Wrong settings returned');
    }

    @IsTest 
    static void shouldGetScheduledInterval() {
        AsyncActionSetting__mdt mockSettings = new AsyncActionSetting__mdt(
            DeveloperName = 'Testing_123',
            ScheduledJobInterval__c = 15
        );
        AsyncActionSettingService.settings = mockSettings;

        Test.startTest();
        Integer interval = AsyncActionSettingService.getScheduledInterval();
        Test.stopTest();

        Assert.areEqual(mockSettings?.ScheduledJobInterval__c?.intValue(), interval, 'Wrong interval returned'); 
    }
}