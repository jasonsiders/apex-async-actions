trigger AsyncActionTrigger on AsyncAction__c(before insert, after insert) {
	new AsyncActionHandler().run();
}
