global abstract class AsyncActionProcessorService {
    @TestVisible
    static Map<String, AsyncActionProcessor__mdt> processors;

    global static Map<String, AsyncActionProcessor__mdt> getAll() {
        // Returns a map of AsyncActionProcessor__mdt records by their "Processor Class" value
        processors = (processors != null) ? processors : AsyncActionProcessorService.retrieve(); 
        return processors;
    }

    global static AsyncActionProcessor__mdt get(String processorName) { 
        // Return a specific AsyncActionProcessor__mdt record by its "Processor Class" value
        return AsyncActionProcessorService.getAll()?.get(processorName);
    }

    static Map<String, AsyncActionProcessor__mdt> retrieve() {
        List<AsyncActionProcessor__mdt> configs = AsyncActionProcessor__mdt.getAll()?.values();
        Map<String, AsyncActionProcessor__mdt> configMap = AsyncActionProcessorService.mapByProcessorClass(configs);
        return configMap;
    }

    @TestVisible
    static Map<String, AsyncActionProcessor__mdt> mapByProcessorClass(List<AsyncActionProcessor__mdt> configs) {
        Map<String, AsyncActionProcessor__mdt> results = new Map<String, AsyncActionProcessor__mdt>(); 
        for (AsyncActionProcessor__mdt config : configs) {
            String processorName = config?.ProcessorClass__c; 
            results?.put(processorName, config);
        }
        return results;
    }
}