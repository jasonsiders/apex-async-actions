@SuppressWarnings('PMD.ApexDoc')
public class AsyncActionTriggerHandler extends AsyncActionTriggerFramework {
	/**
	 * This class handles inserted `AsyncAction__c` records:
	 * - When these records are inserted, they should inherit certain values from their `AsyncActionProcessor__mdt` settings.
	 * - If defined, these records may trigger the corresponding job to be launched.
	 * - Whenever an async action is inserted, we will run the `AsyncActionScheduleEnforcer` logic
	 **/
	private List<AsyncAction__c> actions = (List<AsyncAction__c>) this.triggerNew;

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

	public override Type getType() {
		return AsyncActionTriggerHandler.class;
	}

	private Set<String> getTriggeredActions() {
		// Returns a collection of Processor names of current Action(s) that are configured to run on insert
		Set<String> results = new Set<String>();
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
