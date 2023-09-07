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
            AsyncActionProcessor__mdt config = actual?.get(processorName); 
            Assert.areEqual(processorName, config?.ProcessorClass__c, 'Not mapped by processor'); 
            String developerName = config?.DeveloperName; 
            AsyncActionProcessor__mdt expectedConfig = actual?.get(developerName); 
            Assert.areEqual(config, expectedConfig, 'Config record does not match');
        }
    }

    @IsTest 
    static void shouldAllowDependencyInjection() {
        String processorName = AsyncActionProcessorServiceTest.class.getName();
        AsyncActionProcessor__mdt testConfig = new AsyncActionProcessor__mdt(
            DeveloperName = 'Test_Config',
            ProcessorClass__c = processorName
        ); 
        AsyncActionProcessorService.configs = new Map<String, AsyncActionProcessor__mdt>{processorName => testConfig};

        Test.startTest();
        Map<String, AsyncActionProcessor__mdt> configs = AsyncActionProcessorService.getAll();
        Test.stopTest();

        Assert.areEqual(1, configs?.size(), 'Wrong # of results returned');
        Assert.isTrue(configs?.containsKey(processorName), 'Wrong config mapped');
    }

    @IsTest 
    static void shouldReturnASpecificConfigByItsProcessorClass() { 
        String processorName = AsyncActionProcessorServiceTest.class.getName();
        AsyncActionProcessor__mdt testConfig = new AsyncActionProcessor__mdt(
            DeveloperName = 'Test_Config',
            ProcessorClass__c = processorName
        ); 
        AsyncActionProcessorService.configs = new Map<String, AsyncActionProcessor__mdt>{processorName => testConfig};

        Test.startTest();
        AsyncActionProcessor__mdt config = AsyncActionProcessorService.get(processorName); 
        Test.stopTest(); 

        Assert.isNotNull(config, 'A config was not returned'); 
        Assert.areEqual(processorName, config?.ProcessorClass__c, 'Wrong config returned');
    }
}