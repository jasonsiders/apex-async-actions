public without sharing class AsyncActionRelatedListController {
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
				ProcessorClass__c,
				RelatedRecordId__c,
				Retries__c,
				Scheduled__c,
				Status__c
			FROM AsyncAction__c
			WHERE RelatedRecordId__c = :recordId
			ORDER BY Id DESC
			LIMIT 50000
		];
	}

	@AuraEnabled(cacheable=true)
	public static Boolean hasAccess() {
		return SObjectType.AsyncAction__c?.isAccessible() == true;
	}
}
