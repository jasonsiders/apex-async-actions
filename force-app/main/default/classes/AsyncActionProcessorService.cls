@SuppressWarnings('PMD.ApexDoc')
public abstract class AsyncActionProcessorService {
	@TestVisible
	static Map<String, AsyncActionProcessor__mdt> processors;
	@TestVisible
	static Boolean useRealData = (Test.isRunningTest() == false);

	public static Map<String, AsyncActionProcessor__mdt> getAll() {
		// Returns a map of AsyncActionProcessor__mdt records by their "Processor Class" value
		return processors ?? AsyncActionProcessorService.retrieve();
	}

	public static AsyncActionProcessor__mdt get(String processorName) {
		// Return a specific AsyncActionProcessor__mdt record by its "Processor Class" value
		return AsyncActionProcessorService.getAll()?.get(processorName);
	}

	static Map<String, AsyncActionProcessor__mdt> retrieve() {
		List<AsyncActionProcessor__mdt> configs = AsyncActionProcessorService.useRealData
			? AsyncActionProcessor__mdt.getAll()?.values()
			: new List<AsyncActionProcessor__mdt>();
		Map<String, AsyncActionProcessor__mdt> configMap = AsyncActionProcessorService.mapByProcessorClass(configs);
		return configMap;
	}

	@TestVisible
	static Map<String, AsyncActionProcessor__mdt> mapByProcessorClass(List<AsyncActionProcessor__mdt> configs) {
		Map<String, AsyncActionProcessor__mdt> results = new Map<String, AsyncActionProcessor__mdt>();
		for (AsyncActionProcessor__mdt settings : configs) {
			String processorName = settings?.Processor__c;
			results?.put(processorName, settings);
		}
		return results;
	}
}
