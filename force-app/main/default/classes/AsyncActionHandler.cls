public class AsyncActionHandler extends apxsp.TriggerHandler {
    public override void afterInsert() {
        // Run any jobs configured to run on insert
        List<AsyncAction__c> actions = (List<AsyncAction__c>) this.triggerNew;
        Set<String> triggeredActions = this.getTriggeredActions(actions);
        if (triggeredActions?.isEmpty() == false) {
            AsyncActionStart__e event = new AsyncActionStart__e(); 
            event.Actions__c = String.join(triggeredActions, ',');
            EventBus.publish(event);   
        }
        // Ensure the scheduled job aligns with current configuration
        new AsyncActionScheduleEnforcer()?.enforce();
        new Logger().publish();
    }

    public override Type getType() {
        return AsyncActionHandler.class;
    }

    private Set<String> getTriggeredActions(List<AsyncAction__c> actions) {
        // Returns a collection of ProcessorClass names of current Action(s) that are configured to run on insert
        Set<String> results = new Set<String>();
        for (AsyncAction__c action : actions) {
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