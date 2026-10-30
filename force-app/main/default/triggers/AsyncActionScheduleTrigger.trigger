trigger AsyncActionScheduleTrigger on AsyncActionSchedule__e(after insert) {
	new AsyncActionScheduleTriggerHandler().run();
}
