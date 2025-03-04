@SuppressWarnings('PMD.ApexDoc')
public class AsyncActionStartHandler extends AsyncActionTriggerFramework {
	static final AsyncActionLogger.Adapter LOGGER = AsyncActionLogger.init();

	public override void afterInsert() {
		List<AsyncActionStart__e> events = (List<AsyncActionStart__e>) this.triggerNew;
		List<AsyncActionProcessor__mdt> actions = this.getActionsToLaunch(events);
		new AsyncActionLauncher()?.launch(actions);
		LOGGER?.save(false);
	}

	public override Type getType() {
		return AsyncActionStartHandler.class;
	}

	private List<AsyncActionProcessor__mdt> getActionsToLaunch(List<AsyncActionStart__e> events) {
		Set<AsyncActionProcessor__mdt> actions = new Set<AsyncActionProcessor__mdt>();
		for (String actionName : this.extractActionNames(events)) {
			AsyncActionProcessor__mdt action = AsyncActionProcessorService.get(actionName);
			actions?.add(action);
		}
		actions?.remove(null);
		return new List<AsyncActionProcessor__mdt>(actions);
	}

	private Set<String> extractActionNames(List<AsyncActionStart__e> events) {
		Set<String> actionNames = new Set<String>();
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
