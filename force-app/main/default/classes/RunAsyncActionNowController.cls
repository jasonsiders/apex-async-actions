public with sharing class RunAsyncActionNowController {
    @AuraEnabled 
    public static void runAction(String recordId) {
        try {
            Id actionId = (Id) recordId; 
            List<AsyncAction__c> actions = [
                SELECT Id, ProcessorClass__c, Scheduled__c 
                FROM AsyncAction__c 
                WHERE Id = :actionId
            ];
            AsyncAction__c action = actions?.isEmpty() == false ? actions[0] : null; 
            Boolean scheduledForPast = action?.Scheduled__c != null && action?.Scheduled__c < DateTime.now();
            action.Scheduled__c = (scheduledForPast) ? action?.Scheduled__c : DateTime.now();
            action.Status__c = AsyncActionProcessor.Status.PENDING.name();
            update action; 
            AsyncActionStart__e startEvent = new AsyncActionStart__e(Actions__c = action?.ProcessorClass__c); 
            EventBus.publish(startEvent);
        } catch (Exception anyError) {
            String msg = anyError?.getMessage(); 
            throw new AuraHandledException(msg); 
        }
    }
}