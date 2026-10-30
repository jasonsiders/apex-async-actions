/** @description Runs AsyncActionScheduleEnforcer as the Automated Process user, which then owns the scheduled jobs */
public class AsyncActionScheduleTriggerHandler extends AsyncActionTriggerFramework {
	/** @description Enforces once per batch, since the events carry no data */
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
