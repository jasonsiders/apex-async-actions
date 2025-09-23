@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class AsyncActionScheduledJobServiceTest {
	@IsTest
	static void shouldReturnWhatIsActuallyInOrg() {
		Set<String> settingNames = AsyncActionScheduledJob__mdt.getAll()?.keySet();
		AsyncActionScheduledJobService.useRealData = true;

		Test.startTest();
		List<AsyncActionScheduledJob__mdt> allSettings = AsyncActionScheduledJobService.getAll()?.values();
		for (String settingName : settingNames) {
			AsyncActionScheduledJob__mdt settings = AsyncActionScheduledJobService.get(settingName);
			Assert.areEqual(settingName, settings?.DeveloperName, 'Retrieved wrong CMDT record');
		}
		Test.stopTest();

		Assert.areEqual(settingNames?.size(), allSettings?.size(), 'Wrong # of Settings');
	}

	@IsTest
	static void shouldReturnEmptyMap() {
		// In @IsTest context, the service will return an empty list if there is useRealData = false,
		// and no records have been loaded in via the @TestVisible flags
		Test.startTest();
		Map<String, AsyncActionScheduledJob__mdt> allSettings = AsyncActionScheduledJobService.getAll();
		Test.stopTest();

		Assert.areEqual(0, allSettings?.size(), 'Wrong # of Settings');
	}

	@IsTest
	static void shouldInjectMockSettings() {
		String mockName = 'Test_Setting_' + Crypto.getRandomInteger();
		AsyncActionScheduledJob__mdt mockSettings = new AsyncActionScheduledJob__mdt(
			DeveloperName = mockName,
			Enabled__c = true,
			Interval__c = Integer.valueOf(Math.random() * 60),
			Type__c = 'Semi-Hourly'
		);
		AsyncActionScheduledJobService.settings = new Map<String, AsyncActionScheduledJob__mdt>();
		AsyncActionScheduledJobService.settings?.put(mockName, mockSettings);

		Test.startTest();
		List<AsyncActionScheduledJob__mdt> allSettings = AsyncActionScheduledJobService.getAll()?.values();
		AsyncActionScheduledJob__mdt results = AsyncActionScheduledJobService.get(mockName);
		Test.stopTest();

		Assert.areEqual(1, allSettings?.size(), 'Wrong # of Settings');
		Assert.areEqual(mockSettings?.DeveloperName, results?.DeveloperName, 'Wrong DeveloperName');
		Assert.areEqual(mockSettings?.Enabled__c, results?.Enabled__c, 'Wrong Enabled__c');
		Assert.areEqual(mockSettings?.Interval__c, results?.Interval__c, 'Wrong Interval__c');
		Assert.areEqual(mockSettings?.Type__c, results?.Type__c, 'Wrong Type__c');
	}
}
