trigger AsyncActionStartTrigger on AsyncActionStart__e(after insert) {
	new AsyncActionStartTriggerHandler().run();
}
