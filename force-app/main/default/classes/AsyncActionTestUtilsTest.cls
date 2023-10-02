@IsTest
private class AsyncActionTestUtilsTest {
	@IsTest
	static void shouldInitGlobalSettings() {
		Test.startTest();
		AsyncActionSetting__mdt testSettings = AsyncActionTestUtils.initGlobalSettings();
		Test.stopTest();

		Assert.isNotNull(testSettings, 'Did not initialize a settings record');
		AsyncActionSetting__mdt mockSettings = AsyncActionSettingService.getSettings();
		Assert.areEqual(
			testSettings?.DeveloperName,
			mockSettings?.DeveloperName,
			'Test Settings not returned by service class'
		);
	}

	@IsTest
	static void shouldInitProcessorSettings() {
		Type processorType = AsyncActionTestUtilsTest.class;

		Test.startTest();
		AsyncActionProcessor__mdt testProcessor = AsyncActionTestUtils.initProcessorSettings(processorType);
		Test.stopTest();

		Assert.isNotNull(testProcessor, 'Did not initialize a processor settings record');
		List<AsyncActionProcessor__mdt> allProcessors = AsyncActionProcessorService.getAll()?.values();
		Assert.areEqual(1, allProcessors?.size(), 'Wrong # of Processors mocked');
		AsyncActionProcessor__mdt mockProcessor = allProcessors[0];
		Assert.areEqual(
			testProcessor?.DeveloperName,
			mockProcessor?.DeveloperName,
			'Test Settings not returned by service class'
		);
	}

	@IsTest
	static void shouldMockGlobalSettings() {
		AsyncActionSetting__mdt mock = new AsyncActionSetting__mdt(DeveloperName = 'Testing 123');

		Test.startTest();
		AsyncActionTestUtils.mockGlobalSettings(mock);
		Test.stopTest();

		AsyncActionSetting__mdt settings = AsyncActionSettingService.getSettings();
		Assert.areEqual(mock?.DeveloperName, settings?.DeveloperName, 'Wrong Settings object returned');
	}

	@IsTest
	static void shouldMockProcessorSettings() {
		Set<String> processorNames = new Set<String>{ 'processor_1', 'processor_2', 'processor_3' };

		Test.startTest();
		for (String processorName : processorNames) {
			AsyncActionProcessor__mdt processor = new AsyncActionProcessor__mdt(ProcessorClass__c = processorName);
			AsyncActionTestUtils.mockProcessorSettings(processor);
		}
		Test.stopTest();

		List<AsyncActionProcessor__mdt> allProcessors = AsyncActionProcessorService.getAll()?.values();
		Assert.areEqual(processorNames?.size(), allProcessors?.size(), 'Wrong # of processors');
		for (AsyncActionProcessor__mdt processor : allProcessors) {
			String processorName = processor?.ProcessorClass__c;
			Assert.isTrue(processorNames?.contains(processorName), processorName + ' was not mapped');
		}
	}

	@IsTest
	static void shouldToggleAllowRecursion() {
		Boolean currentVal = AsyncActionProcessor.allowRecursion;
		Boolean newVal = !currentVal;

		Test.startTest();
		AsyncActionTestUtils.setAllowRecursion(newVal);
		Test.stopTest();

		Assert.areEqual(newVal, AsyncActionProcessor.allowRecursion, 'Did not update allowRecursion');
	}
}
