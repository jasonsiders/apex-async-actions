@SuppressWarnings('PMD.AvoidGlobalModifier')
global abstract class AsyncActions {
	// **** STATIC **** //
	global static AsyncAction__c initAction(AsyncActionProcessor__mdt settings, Id relatedRecordId, String data) {
		// Returns a new action related to the current processor type
		return new AsyncAction__c(
			Data__c = data,
			ProcessorName__c = settings?.DeveloperName,
			RelatedRecordId__c = relatedRecordId,
			Retries__c = settings?.Retries__c ?? 0,
			NextEligibleAt__c = DateTime.now(),
			Status__c = AsyncActions.Status.PENDING.name()
		);
	}

	global static AsyncAction__c initAction(AsyncActionProcessor__mdt settings, SObject record, String data) {
		return AsyncActions.initAction(settings, record?.Id, data);
	}

	global static AsyncAction__c initAction(AsyncActionProcessor__mdt settings, Id relatedRecordId) {
		return AsyncActions.initAction(settings, relatedRecordId, null);
	}

	global static AsyncAction__c initAction(AsyncActionProcessor__mdt settings, SObject record) {
		return AsyncActions.initAction(settings, record?.Id);
	}

	global static AsyncAction__c initAction(AsyncActionProcessor__mdt settings) {
		Id nullRecordId = null;
		return AsyncActions.initAction(settings, nullRecordId);
	}

	// **** INNER **** //
	global interface Processor {
		/**
		 * This interface defines the logic to be performed in an Async Action
		 * Create a class that implements this interface,
		 * and list the fully qualified api name of that class in AsyncActionProcessor__mdt.Processor__c
		 **/
		void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions);
	}

	@SuppressWarnings('PMD.FieldNamingConventions')
	global enum Status {
		// Represents the AsyncAction__c.Status__c picklist, offers some type-safety
		// Note: Since picklists are case-sensitive, casing differs from typical enum values
		Pending,
		Completed,
		Failed,
		Canceled
	}
}
