@SuppressWarnings('PMD.ApexDoc')
public with sharing class RunAsyncActionNowController {
	@AuraEnabled
	public static void runAction(String recordId) {
		try {
			Id actionId = (Id) recordId;
			List<AsyncAction__c> actions = [
				SELECT Id, ProcessorName__c, Scheduled__c
				FROM AsyncAction__c
				WHERE Id = :actionId
				WITH SYSTEM_MODE
			];
			AsyncAction__c action = actions?.isEmpty() == false ? actions[0] : null;
			Boolean scheduledForPast = action?.Scheduled__c != null && action?.Scheduled__c < DateTime.now();
			action.Scheduled__c = (scheduledForPast) ? action?.Scheduled__c : DateTime.now();
			action.Status__c = AsyncActionJob.Status.PENDING.name();
			Database.update(action, true, System.AccessLevel.USER_MODE);
			AsyncActionStart__e startEvent = new AsyncActionStart__e(Actions__c = action?.ProcessorName__c);
			EventBus.publish(startEvent);
		} catch (Exception anyError) {
			String msg = anyError?.getMessage();
			throw new AuraHandledException(msg);
		}
	}
}
