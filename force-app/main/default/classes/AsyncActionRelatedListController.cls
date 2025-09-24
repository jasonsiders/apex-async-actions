/**
 * @description Controller class for Lightning Web Components that display AsyncAction records related to a specific SObject record.
 * Provides methods to query and check access to AsyncAction__c records.
 */
public without sharing class AsyncActionRelatedListController {
	/**
	 * @description Retrieves AsyncAction__c records related to a specific record ID.
	 * @param recordId The ID of the record to find related async actions for
	 * @return List of AsyncAction__c records ordered by ID descending, limited to 50,000 records
	 */
	@AuraEnabled(cacheable=true)
	public static List<AsyncAction__c> getActions(String recordId) {
		if (String.isBlank(recordId)) {
			throw new AuraHandledException('Missing Record Id');
		}
		return [
			SELECT
				Id,
				Data__c,
				Error__c,
				CreatedById,
				CreatedBy.Name,
				CreatedDate,
				Name,
				ProcessorName__c,
				RelatedRecordId__c,
				Retries__c,
				NextEligibleAt__c,
				Status__c
			FROM AsyncAction__c
			WHERE RelatedRecordId__c = :recordId
			WITH SYSTEM_MODE
			ORDER BY Id DESC
			LIMIT 50000
		];
	}

	/**
	 * @description Checks if the current user has read access to AsyncAction__c records.
	 * @return True if the user can access AsyncAction__c records, false otherwise
	 */
	@AuraEnabled(cacheable=true)
	public static Boolean hasAccess() {
		return SObjectType.AsyncAction__c?.isAccessible() == true;
	}
}
