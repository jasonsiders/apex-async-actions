@SuppressWarnings('PMD.ApexDoc')
public abstract class AsyncActionProcessorService {
	/**
	 * This class is used to retrieve AsyncActionProcessor__mdt objects from the database
	 * Its `processors` property serves as a seam to inject test records in @IsTest context,
	 * since custom metadata types cannot be manipulated via traditional dml.
	 * See the `AsyncActionTestUtils` class methods to easily inject settings for your apex tests.
	 **/
	@TestVisible
	static Map<String, AsyncActionProcessor__mdt> processors;
	@TestVisible
	static Boolean useRealData = (Test.isRunningTest() == false);

	public static Map<String, AsyncActionProcessor__mdt> getAll() {
		// Returns a map of AsyncActionProcessor__mdt records by their "DeveloperName" values
		return processors ?? AsyncActionProcessorService.retrieve();
	}

	public static AsyncActionProcessor__mdt get(String developerName) {
		// Return a specific AsyncActionProcessor__mdt record by its "DeveloperName" value
		return AsyncActionProcessorService.getAll()?.get(developerName);
	}

	static Map<String, AsyncActionProcessor__mdt> retrieve() {
		List<AsyncActionProcessor__mdt> configs = AsyncActionProcessorService.useRealData
			? AsyncActionProcessor__mdt.getAll()?.values()
			: new List<AsyncActionProcessor__mdt>();
		Map<String, AsyncActionProcessor__mdt> configMap = AsyncActionProcessorService.mapByDeveloperName(configs);
		return configMap;
	}

	@TestVisible
	static Map<String, AsyncActionProcessor__mdt> mapByDeveloperName(List<AsyncActionProcessor__mdt> configs) {
		Map<String, AsyncActionProcessor__mdt> results = new Map<String, AsyncActionProcessor__mdt>();
		for (AsyncActionProcessor__mdt settings : configs) {
			String developerName = settings?.DeveloperName;
			results?.put(developerName, settings);
		}
		return results;
	}
}
