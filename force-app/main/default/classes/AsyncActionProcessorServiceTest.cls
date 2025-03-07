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
			AsyncActionProcessor__mdt processor = actual?.get(processorName);
			Assert.areEqual(processorName, processor?.DeveloperName, 'Not mapped by DeveloperName');
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
		AsyncActionProcessor__mdt testProcessor = new AsyncActionProcessor__mdt(
			DeveloperName = 'Test_Config',
			Processor__c = AsyncActionProcessorServiceTest.class.getName()
		);
		AsyncActionProcessorService.processors = new Map<String, AsyncActionProcessor__mdt>{
			testProcessor?.DeveloperName => testProcessor
		};

		Test.startTest();
		Map<String, AsyncActionProcessor__mdt> processors = AsyncActionProcessorService.getAll();
		Test.stopTest();

		Assert.areEqual(1, processors?.size(), 'Wrong # of results returned');
		Assert.isTrue(processors?.containsKey(testProcessor?.DeveloperName), 'Wrong processor mapped');
	}

	@IsTest
	static void shouldReturnASpecificConfigByItsProcessorClass() {
		AsyncActionProcessor__mdt testProcessor = new AsyncActionProcessor__mdt(
			DeveloperName = 'Test_Config',
			Processor__c = AsyncActionProcessorServiceTest.class.getName()
		);
		AsyncActionProcessorService.processors = new Map<String, AsyncActionProcessor__mdt>{
			testProcessor?.DeveloperName => testProcessor
		};

		Test.startTest();
		AsyncActionProcessor__mdt processor = AsyncActionProcessorService.get(testProcessor?.DeveloperName);
		Test.stopTest();

		Assert.isNotNull(processor, 'A processor was not returned');
		Assert.areEqual(testProcessor?.DeveloperName, processor?.DeveloperName, 'Wrong processor returned');
		Assert.areEqual(testProcessor?.Processor__c, processor?.Processor__c, 'Wrong Processor class');
	}

	@IsTest
	static void shouldMapByDeveloperName() {
		Set<String> classNames = new Set<String>{ 'processor_1', 'processor_2', 'processor_3' };
		List<AsyncActionProcessor__mdt> processors = new List<AsyncActionProcessor__mdt>();
		for (String className : classNames) {
			AsyncActionProcessor__mdt processor = new AsyncActionProcessor__mdt(
				DeveloperName = 'Test_' + className,
				Processor__c = className
			);
			processors?.add(processor);
		}

		Test.startTest();
		Map<String, AsyncActionProcessor__mdt> results = AsyncActionProcessorService.mapByDeveloperName(processors);
		Test.stopTest();

		Assert.areEqual(classNames?.size(), results?.size(), 'Wrong # of AsyncActionProcessor__mdt records mapped');
		for (String className : classNames) {
			String expected = 'Test_' + className;
			Assert.isNotNull(results?.get(expected), 'Did not map ' + expected);
		}
	}
}
