@IsTest 
global class AsyncActionTestUtils {
    global static AsyncActionSetting__mdt initGlobalSettings() {
        // Instantiates and returns a global settings object with default values for testing
        AsyncActionSetting__mdt settings = new AsyncActionSetting__mdt(
            DeveloperName = 'Test_Settings',
            MasterLabel = 'Test Settings',
            RunOnInsert__c = false,
            RunScheduledJob__c = false,
            ScheduledJobInterval__c = 60
        ); 
        AsyncActionTestUtils.mockGlobalSettings(settings); 
        return settings;
    }

    global static AsyncActionProcessor__mdt initProcessorSettings(Type processorType) {
        // Instantiates & returns a processor settings object with default values for testing
        AsyncActionProcessor__mdt processor = new AsyncActionProcessor__mdt(
            BatchSize__c = 200,
            DeveloperName = 'Test_' + processorType?.getName(),
            Enabled__c = true, 
            MasterLabel = 'Test ' + processorType?.getName(),
            ProcessorClass__c = processorType?.getName(),
            Retries__c = 3,
            RetryInterval__c = 3
        ); 
        AsyncActionTestUtils.mockProcessorSettings(processor); 
        return processor; 
    }

    global static void mockGlobalSettings(AsyncActionSetting__mdt settings) {
        // Gives @IsTest access to inject settings records to external callers
        AsyncActionSettingService.settings = settings; 
    }

    global static void mockProcessorSettings(AsyncActionProcessor__mdt processor) {
        // Gives @IsTest access to inject settings records to external callers
        AsyncActionProcessorService.processors = (AsyncActionProcessorService.processors != null) 
            ? AsyncActionProcessorService.processors
            : new Map<String, AsyncActionProcessor__mdt>();
        String processorName = processor?.ProcessorClass__c; 
        AsyncActionProcessorService.processors?.put(processorName, processor); 
    }
}