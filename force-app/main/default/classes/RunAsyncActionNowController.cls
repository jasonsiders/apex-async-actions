public with sharing class RunAsyncActionNowController {
    @AuraEnabled 
    public static void runAction(String recordId) {
        // TODO
        // 1. Query for the Async Action
        // 2. Update the Async Action to "Pending", and Scheduled__c to now (if not in the past)
        // 3. Publish an AsyncActionStart__e event w/the action's class listed
    }
}