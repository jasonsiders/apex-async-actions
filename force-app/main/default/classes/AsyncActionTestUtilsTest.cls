@IsTest
private class AsyncActionTestUtilsTest {
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
	static void shouldInitScheduledJobItems() {
		Type processorType = AsyncActionTestUtilsTest.class;
		AsyncActionProcessor__mdt actionSettings = AsyncActionTestUtils.initProcessorSettings(processorType);
		AsyncActionScheduledJob__mdt jobSettings = AsyncActionTestUtils.initScheduledJobSettings();

		Test.startTest();
		AsyncActionScheduledJobItem__mdt itemSettings = AsyncActionTestUtils.initScheduledJobItem(actionSettings, jobSettings);
		Test.stopTest();
		
		Assert.isNotNull(itemSettings?.DeveloperName, 'AsyncActionScheduledJobItem__mdt.DeveloperName'); 
		Assert.areEqual(actionSettings?.DeveloperName, itemSettings?.AsyncActionProcessor__r?.DeveloperName, 'Wrong AsyncActionProcessor__c');
		Assert.areEqual(jobSettings?.DeveloperName, itemSettings?.ScheduledJob__r?.DeveloperName, 'Wrong ScheduledJob__c');
		Assert.areEqual(1, AsyncActionScheduledJobItemService.getJobItems(jobSettings)?.size(), 'Wrong # of Job Items mocked'); 
	}

	@IsTest 
	static void shouldInitScheduledJobSettings() {
		Test.startTest();
		AsyncActionScheduledJob__mdt jobSettings = AsyncActionTestUtils.initScheduledJobSettings();
		Test.stopTest();

		Assert.isNotNull(jobSettings, 'AsyncActionScheduledJob__mdt');
		Assert.areEqual(1, AsyncActionScheduledJobService.getAll()?.size(), 'Wrong # of Settings mocked');
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
	static void shouldMockScheduledJobItems() {
		Type processorType = AsyncActionTestUtilsTest.class;
		AsyncActionProcessor__mdt actionSettings = AsyncActionTestUtils.initProcessorSettings(processorType);
		AsyncActionScheduledJob__mdt jobSettings = AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionScheduledJobItem__mdt jobItem = new AsyncActionScheduledJobItem__mdt(
			AsyncActionProcessor__r = actionSettings,
			DeveloperName = 'Test_Job_Item_1234',
			ScheduledJob__r = jobSettings
		);

		Test.startTest();
		AsyncActionTestUtils.mockScheduledJobItem(jobItem);
		Test.stopTest();

		List<AsyncActionScheduledJobItem__mdt> mockedItems = AsyncActionScheduledJobItemService.getJobItems(jobSettings);
		Assert.areEqual(1, mockedItems?.size(), 'Wrong # of mocked items');
		AsyncActionScheduledJobItem__mdt mockItem = mockedItems[0];
		Assert.areEqual(actionSettings?.DeveloperName, mockItem?.AsyncActionProcessor__r?.DeveloperName, 'Wrong AsyncActionProcessor__c'); 
		Assert.areEqual(jobItem?.DeveloperName, mockItem?.DeveloperName, 'Wrong DeveloperName');
		Assert.areEqual(jobSettings?.DeveloperName, mockItem?.ScheduledJob__r?.DeveloperName, 'Wrong ScheduledJob__c'); 
	}

	@IsTest 
	static void shouldMockScheduledJobSettings() {
		Set<String> jobNames = new Set<String>{ 'job_1', 'job_2', 'job_3' };

		Test.startTest();
		for (String jobName : jobNames) {
			AsyncActionScheduledJob__mdt job = new AsyncActionScheduledJob__mdt(DeveloperName = jobName);
			AsyncActionTestUtils.mockScheduledJobSettings(job);
		}
		Test.stopTest();

		for (String jobName : jobNames) {
			AsyncActionScheduledJob__mdt job = AsyncActionScheduledJobService.get(jobName);
			Assert.isNotNull(job, 'AsyncActionScheduledJob__mdt');
			Assert.areEqual(jobName, job?.DeveloperName);
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
