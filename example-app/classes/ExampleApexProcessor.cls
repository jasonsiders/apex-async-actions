public without sharing class ExampleApexProcessor implements AsyncActions.Processor {
	/**
	 * This processor can be used to convert leads
	 * It expects the `RelatedRecordId__c` to point to a Lead record,
	 * It expects the `Data__c` field to contain a serialized `Database.LeadConvert` object
	 */
	public void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
		// Use the actions to build a list of LeadConvert objects
		List<Database.LeadConvert> leadConverts = new List<Database.LeadConvert>();
		for (AsyncAction__c action : actions) {
			Database.LeadConvert leadConvert = (Database.LeadConvert) JSON.deserialize(
				action?.Data__c,
				Database.LeadConvert.class
			);
			leadConverts?.add(leadConvert);
		}
		// Convert the leads
		List<Database.LeadConvertResult> results = Database.convertLead(
			leadConverts,
			false,
			System.AccessLevel.SYSTEM_MODE
		);
		for (Integer i = 0; i < results?.size(); i++) {
			AsyncAction__c action = actions?.get(i);
			Database.LeadConvertResult result = results?.get(i);
			if (result?.isSuccess() == true) {
				// Mark the action as completed
				action.Status__c = AsyncActions.Status.COMPLETED.name();
			} else {
				// Use the AsyncActions.Failure class to handle the error
				// Depending on the number of retries remaining,
				// the action's Retries may be decremented,
				// or its Status may be set as "Failed" if none remain
				Database.Error error = result?.getErrors()?.get(0);
				new AsyncActions.Failure(settings)?.fail(action, error);
			}
		}
	}
}
