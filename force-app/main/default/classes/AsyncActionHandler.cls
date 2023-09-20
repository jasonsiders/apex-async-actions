public class AsyncActionHandler extends apxsp.TriggerHandler {
    public override void afterInsert() {
        // If Run on Insert, wake the job
        // TODO: Revamp this logic
        /* if (AsyncActionSettingService.getSettings()?.RunOnInsert__c == true) {
            AsyncActionStart__e event = new AsyncActionStart__e();
            EventBus.publish(event);
        } */
        // Ensure the scheduled job aligns with current settings
        new AsyncActionScheduleEnforcer()?.enforce();
        apxsp.Logger.publish();
    }

    public override Type getType() {
        return AsyncActionHandler.class;
    }
}