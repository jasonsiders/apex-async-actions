trigger AsyncActionTrigger on AsyncAction__c(before insert, after insert) {
	new AsyncActionTriggerHandler().run();
}
