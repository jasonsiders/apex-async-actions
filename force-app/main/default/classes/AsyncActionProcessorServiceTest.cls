@IsTest 
private class AsyncActionProcessorServiceTest {
    @IsTest 
    static void shouldReturnWhatIsInOrg() {
        Map<String, AsyncActionProcessor__mdt> expected = AsyncActionProcessor__mdt.getAll();
        
        Test.startTest();
        Map<String, AsyncActionProcessor__mdt> actual = AsyncActionProcessorService.getAll();
        Test.stopTest();

        Assert.areEqual(expected?.size(), actual?.size(), 'Wrong # of results returned');
        for (String processorName : actual?.keySet()) {
            AsyncActionProcessor__mdt processor = actual?.get(processorName); 
            Assert.areEqual(processorName, processor?.ProcessorClass__c, 'Not mapped by processor'); 
            String developerName = processor?.DeveloperName; 
            AsyncActionProcessor__mdt expectedConfig = actual?.get(developerName); 
            Assert.areEqual(processor, expectedConfig, 'Config record does not match');
        }
    }

    @IsTest 
    static void shouldAllowDependencyInjection() {
        String processorName = AsyncActionProcessorServiceTest.class.getName();
        AsyncActionProcessor__mdt testProcessor = new AsyncActionProcessor__mdt(
            DeveloperName = 'Test_Config',
            ProcessorClass__c = processorName
        ); 
        AsyncActionProcessorService.processors = new Map<String, AsyncActionProcessor__mdt>{processorName => testProcessor};

        Test.startTest();
        Map<String, AsyncActionProcessor__mdt> processors = AsyncActionProcessorService.getAll();
        Test.stopTest();

        Assert.areEqual(1, processors?.size(), 'Wrong # of results returned');
        Assert.isTrue(processors?.containsKey(processorName), 'Wrong processor mapped');
    }

    @IsTest 
    static void shouldReturnASpecificConfigByItsProcessorClass() { 
        String processorName = AsyncActionProcessorServiceTest.class.getName();
        AsyncActionProcessor__mdt testProcessor = new AsyncActionProcessor__mdt(
            DeveloperName = 'Test_Config',
            ProcessorClass__c = processorName
        ); 
        AsyncActionProcessorService.processors = new Map<String, AsyncActionProcessor__mdt>{processorName => testProcessor};

        Test.startTest();
        AsyncActionProcessor__mdt processor = AsyncActionProcessorService.get(processorName); 
        Test.stopTest(); 

        Assert.isNotNull(processor, 'A processor was not returned'); 
        Assert.areEqual(processorName, processor?.ProcessorClass__c, 'Wrong processor returned');
    }
}