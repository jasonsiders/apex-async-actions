/**
 * @description Trigger handler for AsyncActionSchedule__e platform events.
 * Runs AsyncActionScheduleEnforcer logic as the Automated Process user,
 * so that the scheduled jobs it creates are owned by that user.
 */
public class AsyncActionScheduleTriggerHandler extends AsyncActionTriggerFramework {
	/** @description Runs the enforcer in this trigger, since only here does it run as the Automated Process user */
	public override void afterInsert() {
		new AsyncActionScheduleEnforcer()?.enforce();
		AsyncActionLogger.save();
	}

	/**
	 * @description Returns the Type of this trigger handler class
	 * @return Type of AsyncActionScheduleTriggerHandler
	 */
	public override Type getType() {
		return AsyncActionScheduleTriggerHandler.class;
	}
}
