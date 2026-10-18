/**
 * @description Service class for retrieving AsyncActionParameter__mdt values by DeveloperName.
 * The parameters property serves as a seam to inject test records in @IsTest context,
 * since custom metadata types cannot be manipulated via traditional DML.
 * See AsyncActionTestUtils.mockParameter to easily inject parameters for your apex tests.
 */
public abstract class AsyncActionParameterService {
	@TestVisible
	static Map<String, AsyncActionParameter__mdt> parameters;

	/**
	 * @description Retrieves the value of a named AsyncActionParameter__mdt record.
	 * Records are cached for the remainder of the transaction; getAll() consumes no SOQL.
	 * @param developerName The DeveloperName of the parameter to retrieve
	 * @return The Value__c of the matching parameter, or null if not found
	 */
	public static String getParameter(String developerName) {
		parameters = parameters ?? AsyncActionParameter__mdt.getAll();
		return parameters?.get(developerName)?.Value__c;
	}
}
