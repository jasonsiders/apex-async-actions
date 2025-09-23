public without sharing class AsyncActionRelatedListController {
	/**
	 * This class provides controller methods for LWCs that display AsyncAction records related to a specific SObject record
	 **/
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

	@AuraEnabled(cacheable=true)
	public static Boolean hasAccess() {
		return SObjectType.AsyncAction__c?.isAccessible() == true;
	}
}
