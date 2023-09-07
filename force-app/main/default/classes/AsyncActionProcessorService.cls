global abstract class AsyncActionProcessorService {
    @TestVisible
    static Map<String, AsyncActionProcessor__mdt> configs;

    global static Map<String, AsyncActionProcessor__mdt> getAll() {
        // Returns a map of AsyncActionProcessor__mdt records by their "Processor Class" value
        configs = (configs != null) ? configs : AsyncActionProcessorService.retrieve(); 
        return configs;
    }

    global static AsyncActionProcessor__mdt get(String processorName) { 
        // Return a specific AsyncActionProcessor__mdt record by its "Processor Class" value
        return AsyncActionProcessorService.getAll()?.get(processorName);
    }

    static Map<String, AsyncActionProcessor__mdt> retrieve() {
        Map<String, AsyncActionProcessor__mdt> configMap = new Map<String, AsyncActionProcessor__mdt>();
        for (AsyncActionProcessor__mdt config : AsyncActionProcessor__mdt.getAll().values()) {
            String processorName = config?.ProcessorClass__c; 
            configMap?.put(processorName, config);
        }
        return configMap;
    }
}