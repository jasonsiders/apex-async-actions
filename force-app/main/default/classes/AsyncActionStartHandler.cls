public class AsyncActionStartHandler extends apxsp.TriggerHandler {
    public override void afterInsert() {
        List<AsyncActionStart__e> events = (List<AsyncActionStart__e>) this.triggerNew;
        List<AsyncActionProcessor__mdt> actions = this.getActionsToLaunch(events);
        AsyncActionLauncher.launchJobs(actions, null);
        apxsp.Logger.publish();
    }
    
    public override Type getType() {
        return AsyncActionStartHandler.class;
    }

    private List<AsyncActionProcessor__mdt> getActionsToLaunch(List<AsyncActionStart__e> events) {
        Map<String, AsyncActionProcessor__mdt> actionMap = new Map<String, AsyncActionProcessor__mdt>();
        for (AsyncActionStart__e event : events) {
            System.debug('Actions__c: ' + event?.Actions__c);
            if (String.isNotBlank(event?.Actions__c)) {
                // If Actions__c are specified, launch only the jobs specified in the field
                List<String> specifiedActions = event?.Actions__c?.replaceAll('\\s', '')?.split(',');
                System.debug('Specified Actions: ' + JSON.serialize(specifiedActions));
                for (String actionName : specifiedActions) {
                    AsyncActionProcessor__mdt action = AsyncActionProcessorService.get(actionName);
                    System.debug(actionName + ': ' + action);
                    if (action != null) {
                        actionMap?.put(actionName, action);
                    }
                }
            } else {
                // If Actions__c are not specified, launch all jobs
                Map<String, AsyncActionProcessor__mdt> allActions = AsyncActionProcessorService.getAll();
                actionMap?.putAll(allActions);
                break;
            }
        }
        System.debug('Returning ' + JSON.serialize(actionMap?.values()));
        return actionMap?.values();
    }
}