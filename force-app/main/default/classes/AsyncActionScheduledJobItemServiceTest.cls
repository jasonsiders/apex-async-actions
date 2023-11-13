@IsTest
private class AsyncActionScheduledJobItemServiceTest {
	@IsTest
	static void shouldReturnCmdtsFromOrg() {
		String jobName = 'Testing_123';
		AsyncActionScheduledJob__mdt jobSettings = new AsyncActionScheduledJob__mdt();
		jobSettings.DeveloperName = jobName;
		AsyncActionScheduledJobItemService.useRealData = true; 
		List<AsyncActionScheduledJobItem__mdt> allItems = [
			SELECT Id
			FROM AsyncActionScheduledJobItem__mdt
			WHERE ScheduledJob__r.DeveloperName = :jobName
		];

		Test.startTest();
		List<AsyncActionScheduledJobItem__mdt> items = AsyncActionScheduledJobItemService.getJobItems(jobSettings);
		Test.stopTest();

		Assert.areEqual(allItems?.size(), items?.size(), 'Wrong # of Items');
	}

	@IsTest
	static void shouldReturnEmptyList() {
		// In @IsTest context, the service will return an empty list if there is useRealData = false,
		// and no records have been loaded in via the @TestVisible flags
		String jobName = 'Testing_123';
		AsyncActionScheduledJob__mdt jobSettings = new AsyncActionScheduledJob__mdt();
		jobSettings.DeveloperName = jobName;

		Test.startTest();
		List<AsyncActionScheduledJobItem__mdt> items = AsyncActionScheduledJobItemService.getJobItems(jobSettings);
		Test.stopTest();

		Assert.areEqual(0, items?.size(), 'Wrong # of Items');
	}

	@IsTest
	static void shouldAllowDependencyInjection() {
		String jobName = 'Testing_123';
		AsyncActionScheduledJob__mdt jobSettings = new AsyncActionScheduledJob__mdt();
		jobSettings.DeveloperName = jobName;
		// Generate mock job items
		List<AsyncActionScheduledJobItem__mdt> mockItems = new List<AsyncActionScheduledJobItem__mdt>();
		for (Integer i = 0; i < 200; i++) {
			AsyncActionScheduledJobItem__mdt mockItem = new AsyncActionScheduledJobItem__mdt(
				AsyncActionProcessor__r = new AsyncActionProcessor__mdt(DeveloperName = 'Mock_Action_' + i),
				DeveloperName = 'Mock_Item_' + i,
				Enabled__c = true,
				ScheduledJob__r = jobSettings
			);
			mockItems?.add(mockItem);
		}
		AsyncActionScheduledJobItemService.jobItems?.put(jobName, mockItems);

		Test.startTest();
		List<AsyncActionScheduledJobItem__mdt> items = AsyncActionScheduledJobItemService.getJobItems(jobSettings);
		Test.stopTest();

		Assert.areEqual(mockItems?.size(), items?.size(), 'Wrong # of items mocked');
	}
}
