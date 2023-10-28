@IsTest 
private class AsyncActionScheduledJobServiceTest {
    @IsTest 
    static void shouldReturnWhatIsActuallyInOrg() {
        Set<String> settingNames = AsyncActionScheduledJob__mdt.getAll()?.keySet();

        Test.startTest();
        for (String settingName : settingNames) {
            AsyncActionScheduledJob__mdt settings = AsyncActionScheduledJobService.get(settingName);
            Assert.areEqual(settingName, settings?.DeveloperName, 'Retrieved wrong CMDT record');
        }
        Test.stopTest();
    }

    @IsTest 
    static void shouldInjectMockSettings() {
        String mockName = 'Test_Setting_' + Crypto.getRandomInteger();
        AsyncActionScheduledJob__mdt mockSettings = new AsyncActionScheduledJob__mdt(
            DeveloperName = mockName,
            Enabled__c = true,
            Interval__c = Integer.valueOf(Math.random() * 60)
        );
        AsyncActionScheduledJobService.settings = new Map<String, AsyncActionScheduledJob__mdt>();
        AsyncActionScheduledJobService.settings?.put(mockName, mockSettings);

        Test.startTest();
        AsyncActionScheduledJob__mdt results = AsyncActionScheduledJobService.get(mockName);
        Test.stopTest();

        Assert.areEqual(mockSettings?.DeveloperName, results?.DeveloperName, 'Wrong DeveloperName');
        Assert.areEqual(mockSettings?.Enabled__c, results?.Enabled__c, 'Wrong Enabled__c');
        Assert.areEqual(mockSettings?.Interval__c, results?.Interval__c, 'Wrong Interval__c');
    }
}