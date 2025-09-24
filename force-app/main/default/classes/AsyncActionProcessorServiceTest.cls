@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class AsyncActionProcessorServiceTest {
	@IsTest
	static void shouldReturnWhatIsInOrg() {
		// In @IsTest context, the service class will not use org data by default.
		// This is to avoid unexpected behaviors while testing in live environments.
		// If needed, callers can use the @TestVisible flag to bypass this behavior.
		Map<String, AsyncActionProcessor__mdt> expected = AsyncActionProcessor__mdt.getAll();
		AsyncActionProcessorService.useRealData = true;

		Test.startTest();
		Map<String, AsyncActionProcessor__mdt> actual = AsyncActionProcessorService.getAll();
		Test.stopTest();

		Assert.areEqual(expected?.size(), actual?.size(), 'Wrong # of results returned');
		for (String processorName : actual?.keySet()) {
			AsyncActionProcessor__mdt settings = actual?.get(processorName);
			Assert.areEqual(processorName, settings?.DeveloperName, 'Not mapped by DeveloperName');
		}
	}

	@IsTest
	static void shouldReturnNothing() {
		// In @IsTest context, the service will return an empty list if there is useRealData = false,
		// and no records have been loaded in via the @TestVisible flags
		Test.startTest();
		Map<String, AsyncActionProcessor__mdt> actual = AsyncActionProcessorService.getAll();
		Test.stopTest();

		Assert.areEqual(0, actual?.size(), 'Wrong # of results returned');
	}

	@IsTest
	static void shouldAllowDependencyInjection() {
		AsyncActionProcessor__mdt testSettings = new AsyncActionProcessor__mdt(
			DeveloperName = 'Test_Config',
			Processor__c = AsyncActionProcessorServiceTest.class.getName()
		);
		AsyncActionProcessorService.processors = new Map<String, AsyncActionProcessor__mdt>{
			testSettings?.DeveloperName => testSettings
		};

		Test.startTest();
		Map<String, AsyncActionProcessor__mdt> results = AsyncActionProcessorService.getAll();
		Test.stopTest();

		Assert.areEqual(1, results?.size(), 'Wrong # of results returned');
		Assert.isTrue(results?.containsKey(testSettings?.DeveloperName), 'Wrong processor mapped');
	}

	@IsTest
	static void shouldReturnASpecificConfigByItsProcessorClass() {
		AsyncActionProcessor__mdt testSettings = new AsyncActionProcessor__mdt(
			DeveloperName = 'Test_Config',
			Processor__c = AsyncActionProcessorServiceTest.class.getName()
		);
		AsyncActionProcessorService.processors = new Map<String, AsyncActionProcessor__mdt>{
			testSettings?.DeveloperName => testSettings
		};

		Test.startTest();
		AsyncActionProcessor__mdt result = AsyncActionProcessorService.get(testSettings?.DeveloperName);
		Test.stopTest();

		Assert.isNotNull(result, 'A processor was not returned');
		Assert.areEqual(testSettings?.DeveloperName, result?.DeveloperName, 'Wrong processor returned');
		Assert.areEqual(testSettings?.Processor__c, result?.Processor__c, 'Wrong Processor class');
	}

	@IsTest
	static void shouldMapByDeveloperName() {
		Set<String> processorNames = new Set<String>{ 'processor_1', 'processor_2', 'processor_3' };
		List<AsyncActionProcessor__mdt> testSettings = new List<AsyncActionProcessor__mdt>{};
		for (String processorName : processorNames) {
			AsyncActionProcessor__mdt testSetting = new AsyncActionProcessor__mdt(DeveloperName = processorName);
			testSettings?.add(testSetting);
		}

		Test.startTest();
		Map<String, AsyncActionProcessor__mdt> results = AsyncActionProcessorService.mapByDeveloperName(testSettings);
		Test.stopTest();

		Assert.areEqual(processorNames?.size(), results?.size(), 'Wrong # of AsyncActionProcessor__mdt records mapped');
		for (String processorName : processorNames) {
			Assert.isNotNull(results?.get(processorName), 'Did not map ' + processorName);
		}
	}
}
