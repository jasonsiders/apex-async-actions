/**
 * @description Trigger handler for AsyncAction__c records.
 * Handles inserted AsyncAction__c records by:
 * - Inheriting values from their AsyncActionProcessor__mdt settings
 * - Triggering corresponding jobs to be launched if defined
 * - Running AsyncActionScheduleEnforcer logic
 */
public class AsyncActionTriggerHandler extends AsyncActionTriggerFramework {
	private List<AsyncAction__c> actions = (List<AsyncAction__c>) this.triggerNew;

	/**
	 * @description Sets the number of retries based on configured metadata or 0 if none specified.
	 */
	public override void beforeInsert() {
		// Set the # of Retries based on the configured metadata - or 0, if none specified
		for (AsyncAction__c action : this.actions) {
			// Do not overwrite non-null values
			if (action?.Retries__c == null) {
				String processorName = action?.ProcessorName__c;
				action.Retries__c = AsyncActionProcessorService.get(processorName)?.Retries__c ?? 0;
			}
		}
	}

	/**
	 * @description Runs jobs configured to run on insert and ensures scheduled jobs align with current configuration.
	 */
	public override void afterInsert() {
		// Run any jobs configured to run on insert
		Set<String> triggeredActions = this.getTriggeredActions();
		if (triggeredActions?.isEmpty() == false) {
			AsyncActionStart__e event = new AsyncActionStart__e();
			event.Actions__c = String.join(triggeredActions, ',');
			EventBus.publish(event);
		}
		// Ensure the scheduled job aligns with current configuration
		new AsyncActionScheduleEnforcer()?.enforce();
		AsyncActionLogger.save();
	}

	/**
	 * @description Returns the Type of this trigger handler class.
	 * @return Type of AsyncActionTriggerHandler
	 */
	public override Type getType() {
		return AsyncActionTriggerHandler.class;
	}

	private Set<String> getTriggeredActions() {
		// Returns a collection of Processor names of current Action(s) that are configured to run on insert
		Set<String> results = new Set<String>{};
		for (AsyncAction__c action : this.actions) {
			String processorName = action?.ProcessorName__c;
			if (
				results?.contains(processorName) == false &&
				AsyncActionProcessorService.get(processorName)?.RunOnInsert__c == true
			) {
				results?.add(processorName);
			}
		}
		return results;
	}
}
