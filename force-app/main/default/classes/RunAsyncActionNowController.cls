/**
 * @description Controller class that allows Lightning Web Components to run AsyncAction__c records on-demand.
 * Bypasses current NextEligibleAt__c or Status__c values to execute actions immediately.
 */
public with sharing class RunAsyncActionNowController {
	/**
	 * @description Executes an AsyncAction__c record immediately by updating its status and publishing a start event.
	 * @param recordId The ID of the AsyncAction__c record to execute
	 */
	@AuraEnabled
	public static void runAction(String recordId) {
		try {
			Id actionId = (Id) recordId;
			List<AsyncAction__c> actions = [
				SELECT Id, ProcessorName__c, NextEligibleAt__c
				FROM AsyncAction__c
				WHERE Id = :actionId
				WITH SYSTEM_MODE
			];
			AsyncAction__c action = actions?.isEmpty() == false ? actions[0] : null;
			Boolean scheduledForPast = action?.NextEligibleAt__c != null && action?.NextEligibleAt__c < DateTime.now();
			action.NextEligibleAt__c = (scheduledForPast) ? action?.NextEligibleAt__c : DateTime.now();
			action.Status__c = AsyncActions.Status.PENDING.name();
			Database.update(action, true, System.AccessLevel.USER_MODE);
			AsyncActionStart__e startEvent = new AsyncActionStart__e(Actions__c = action?.ProcessorName__c);
			EventBus.publish(startEvent);
		} catch (Exception anyError) {
			String msg = anyError?.getMessage();
			throw new AuraHandledException(msg);
		}
	}
}
