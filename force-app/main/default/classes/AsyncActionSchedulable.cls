public class AsyncActionSchedulable extends apxsp.Reschedulable {
    static final Integer DEFAULT_INTERVAL = 60; 
    AsyncActionSetting__mdt settings = AsyncActionSettingService.getSettings();

    public override void doScheduledActions(System.SchedulableContext context) {
        if (this.settings?.RunScheduledJob__c == true) {
            AsyncActionStart__e event = new AsyncActionStart__e();
            EventBus.publish(event); 
        } 
    }

    public override Integer getInterval() {
        Integer interval = AsyncActionSettingService.getSettings()?.ScheduledJobInterval__c?.intValue();
        return (interval != null) ? interval : DEFAULT_INTERVAL; 
    }
    
    public override Type getType() {
        return AsyncActionSchedulable.class;
    }

    public override Id scheduleNewJob() {
        // If the Scheduled Job is disabled, do not reschedule
        Boolean isEnabled = this.settings?.RunScheduledJob__c == true;
        Id jobId = (isEnabled) ? super.scheduleNewJob() : null;
        apxsp.Logger.finest(this.getType() + ' enabled? ' + isEnabled + ' -> ' + jobId);
        return jobId; 
    }
}