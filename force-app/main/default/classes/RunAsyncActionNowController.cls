@SuppressWarnings('PMD.ApexDoc')
public with sharing class RunAsyncActionNowController {
	/**
	 * This class exposes a method which allows LWC consumers to run an `AsyncAction__c` record on-demand,
	 * regardless of its current `NextEligibleAt__c` or `Status__c` values
	 **/
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
