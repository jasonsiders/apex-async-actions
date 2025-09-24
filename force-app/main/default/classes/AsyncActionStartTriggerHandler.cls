/**
 * @description Trigger handler for AsyncActionStart__e platform events.
 * Handles published AsyncActionStart__e platform events by launching AsyncActionJobs
 * that correspond with the event's Actions__c field, or all if none specified.
 */
public class AsyncActionStartTriggerHandler extends AsyncActionTriggerFramework {
	/**
	 * @description Processes AsyncActionStart__e events and launches corresponding AsyncActionJobs.
	 */
	public override void afterInsert() {
		List<AsyncActionStart__e> events = (List<AsyncActionStart__e>) this.triggerNew;
		List<AsyncActionProcessor__mdt> actions = this.getActionsToLaunch(events);
		new AsyncActionLauncher()?.launch(actions);
		AsyncActionLogger.save();
	}

	/**
	 * @description Returns the Type of this trigger handler class.
	 * @return Type of AsyncActionStartTriggerHandler
	 */
	public override Type getType() {
		return AsyncActionStartTriggerHandler.class;
	}

	private List<AsyncActionProcessor__mdt> getActionsToLaunch(List<AsyncActionStart__e> events) {
		Map<String, AsyncActionProcessor__mdt> actions = new Map<String, AsyncActionProcessor__mdt>{};
		for (String actionName : this.extractActionNames(events)) {
			AsyncActionProcessor__mdt action = AsyncActionProcessorService.get(actionName);
			actions?.put(actionName, action);
		}
		actions?.remove(null);
		return actions?.values();
	}

	private Set<String> extractActionNames(List<AsyncActionStart__e> events) {
		Set<String> actionNames = new Set<String>{};
		for (AsyncActionStart__e event : events) {
			if (String.isNotBlank(event?.Actions__c)) {
				// If Actions__c are specified, launch only the jobs specified in the field
				List<String> specifiedActions = event?.Actions__c?.replaceAll('\\s', '')?.split(',');
				actionNames?.addAll(specifiedActions);
			} else {
				// If Actions__c are not specified, launch all jobs
				Set<String> allActionNames = AsyncActionProcessorService.getAll()?.keySet();
				actionNames?.addAll(allActionNames);
				break;
			}
		}
		return actionNames;
	}
}
