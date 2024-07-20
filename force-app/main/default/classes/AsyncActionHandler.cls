public class AsyncActionHandler extends AsyncActionTriggerFramework {
	private List<AsyncAction__c> actions = (List<AsyncAction__c>) this.triggerNew;

	public override void beforeInsert() {
		// Set the # of Retries based on the configured metadata - or 0, if none specified
		for (AsyncAction__c action : this.actions) {
			// Do not overwrite non-null values
			if (action?.Retries__c == null) {
				String className = action?.ProcessorClass__c;
				action.Retries__c = AsyncActionProcessorService.get(className)?.Retries__c ?? 0; 
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
		AsyncActionLogger.init()?.save(false);
	}

	public override Type getType() {
		return AsyncActionHandler.class;
	}

	private Set<String> getTriggeredActions() {
		// Returns a collection of ProcessorClass names of current Action(s) that are configured to run on insert
		Set<String> results = new Set<String>();
		for (AsyncAction__c action : this.actions) {
			String actionName = action?.ProcessorClass__c;
			if (
				results?.contains(actionName) == false &&
				AsyncActionProcessorService.get(actionName)?.RunOnInsert__c == true
			) {
				results?.add(actionName);
			}
		}
		return results;
	}
}
