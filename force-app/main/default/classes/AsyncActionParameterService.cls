/**
 * @description Reads package-wide AsyncActionParameter__mdt values by DeveloperName, so each setting is its own
 * record and a plugin package can ship one without overwriting a subscriber's configuration
 */
public abstract class AsyncActionParameterService {
	/** @description Cached for the transaction; also a seam for tests, since custom metadata can't be inserted via DML **/
	@TestVisible
	static Map<String, AsyncActionParameter__mdt> parameters;

	/**
	 * @description Loads every parameter on first read; getAll() costs no SOQL, and callers read on each log or enqueue
	 * @param developerName The DeveloperName of the parameter to retrieve
	 * @return The Value__c of the matching parameter, or null if not found
	 */
	public static String getParameter(String developerName) {
		parameters = parameters ?? AsyncActionParameter__mdt.getAll();
		return parameters?.get(developerName)?.Value__c;
	}
}
