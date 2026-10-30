/** @description Runs AsyncActionScheduleEnforcer as the Automated Process user, which then owns the scheduled jobs */
public class AsyncActionScheduleTriggerHandler extends AsyncActionTriggerFramework {
	/** @description Enforces once per batch, since the events carry no data. Logs failures, since no caller sees them */
	public override void afterInsert() {
		try {
			new AsyncActionScheduleEnforcer()?.enforce();
		} catch (Exception error) {
			AsyncActionLogger.log(System.LoggingLevel.ERROR, error);
			throw error;
		} finally {
			AsyncActionLogger.save();
		}
	}

	/**
	 * @description Returns the Type of this trigger handler class
	 * @return Type of AsyncActionScheduleTriggerHandler
	 */
	public override Type getType() {
		return AsyncActionScheduleTriggerHandler.class;
	}
}
