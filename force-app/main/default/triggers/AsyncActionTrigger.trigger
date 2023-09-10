trigger AsyncActionTrigger on AsyncAction__c (after insert) {
    new AsyncActionHandler().run();
}