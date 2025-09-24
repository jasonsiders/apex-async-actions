/**
 * @description Service class for retrieving AsyncActionProcessor__mdt objects from the database.
 * The processors property serves as a seam to inject test records in @IsTest context,
 * since custom metadata types cannot be manipulated via traditional DML.
 * See the AsyncActionTestUtils class methods to easily inject settings for your apex tests.
 */
public abstract without sharing class AsyncActionProcessorService {
	@TestVisible
	static Map<String, AsyncActionProcessor__mdt> processors;
	@TestVisible
	static Boolean useRealData = (Test.isRunningTest() == false);

	/**
	 * @description Returns a map of all AsyncActionProcessor__mdt records by their DeveloperName values.
	 * @return Map of AsyncActionProcessor__mdt records keyed by DeveloperName
	 */
	public static Map<String, AsyncActionProcessor__mdt> getAll() {
		// Returns a map of AsyncActionProcessor__mdt records by their "DeveloperName" values
		return processors ?? AsyncActionProcessorService.retrieve();
	}

	/**
	 * @description Returns a specific AsyncActionProcessor__mdt record by its DeveloperName value.
	 * @param developerName The DeveloperName of the processor to retrieve
	 * @return AsyncActionProcessor__mdt record or null if not found
	 */
	public static AsyncActionProcessor__mdt get(String developerName) {
		// Return a specific AsyncActionProcessor__mdt record by its "DeveloperName" value
		return AsyncActionProcessorService.getAll()?.get(developerName);
	}

	@TestVisible
	private static Map<String, AsyncActionProcessor__mdt> mapByDeveloperName(List<AsyncActionProcessor__mdt> configs) {
		Map<String, AsyncActionProcessor__mdt> results = new Map<String, AsyncActionProcessor__mdt>{};
		for (AsyncActionProcessor__mdt settings : configs) {
			String developerName = settings?.DeveloperName;
			results?.put(developerName, settings);
		}
		return results;
	}

	private static Map<String, AsyncActionProcessor__mdt> retrieve() {
		List<AsyncActionProcessor__mdt> configs = AsyncActionProcessorService.useRealData
			? AsyncActionProcessorService.queryAllProcessors()
			: new List<AsyncActionProcessor__mdt>{};
		Map<String, AsyncActionProcessor__mdt> configMap = AsyncActionProcessorService.mapByDeveloperName(configs);
		return configMap;
	}

	private static List<AsyncActionProcessor__mdt> queryAllProcessors() {
		// Build & execute a dynamic query that includes all fields on the processor object, and returns all processor records
		// Note: Custom Metadata's built in getAll() method doesn't return values for long text area fields, like Data__c
		Set<String> fieldNames = SObjectType.AsyncActionProcessor__mdt.fields.getMap()?.keySet();
		String queryString = String.format(
			'SELECT {0} FROM {1} WITH SYSTEM_MODE',
			new List<String>{ String.join(fieldNames, ', '), AsyncActionProcessor__mdt.SObjectType.toString() }
		);
		return Database.query(queryString);
	}
}
