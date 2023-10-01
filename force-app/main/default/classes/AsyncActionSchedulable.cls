public class AsyncActionSchedulable implements System.Schedulable {
    static final Integer DEFAULT_INTERVAL = 60; 
    AsyncActionSetting__mdt settings = AsyncActionSettingService.getSettings();
    static final Logger LOGGER = new Logger()
        ?.setLoggedFrom(AsyncActionSchedulable.class)
        ?.setSource(AsyncActionConstants.PACKAGE_NAME);

    public void execute(System.SchedulableContext context) {
        this.doScheduledActions(context);
        this.reschedule(context?.getTriggerId());
    }

    public void abortJobs(List<AsyncApexJob> jobs) {
        for (AsyncApexJob job : jobs) {
            String jobName = job?.CronTrigger?.CronJobDetail?.Name;
            Id jobId = job?.CronTriggerId;
            if (jobId != null) {
                LOGGER?.finest('Aborting ' + jobName + ' [' + jobId + ']');
                System.abortJob(jobId);
            }
        }
    }

    public Id scheduleNewJob() {
        // If the Scheduled Job is disabled, do not reschedule
        Id jobId;
        Boolean isEnabled =  this.settings?.RunScheduledJob__c == true;
        if (isEnabled) {
            String jobName = AsyncActionSchedulable.class?.getName();
            String cronExp = Cron.hourly().minutesFromNow(this.getInterval())?.expression();
            jobId = System.schedule(jobName, cronExp, new AsyncActionSchedulable());
            LOGGER?.finest('Scheduled new job: ' + jobId + '|' + jobName + '|' + cronExp);
        }
        LOGGER?.finest(AsyncActionSchedulable.class + ' enabled? ' + isEnabled + ' -> ' + jobId);
        return jobId;
    }

    private void doScheduledActions(System.SchedulableContext context) {
        if (this.settings?.RunScheduledJob__c == true) {
            AsyncActionStart__e event = new AsyncActionStart__e();
            EventBus.publish(event); 
        } 
    }

    private Integer getInterval() {
        Integer interval = AsyncActionSettingService.getSettings()?.ScheduledJobInterval__c?.intValue();
        return (interval != null) ? interval : DEFAULT_INTERVAL; 
    }

    private List<AsyncApexJob> getPendingJobs() {
        return [
            SELECT Id, CronTriggerId, CronTrigger.CronExpression, CronTrigger.CronJobDetail.Name, Status
			FROM AsyncApexJob
			WHERE
				ApexClass.Name = :AsyncActionSchedulable.class.getName()
				AND Status IN ('Holding', 'Preparing', 'Processing', 'Queued')
			ORDER BY CreatedDate ASC 
        ];
    }

    private Id reschedule(Id currentJobId) {
        // Deletes any existing jobs of this type, then schedules a new one for the defined interval
        List<AsyncApexJob> pendingJobs = this.getPendingJobs();
        this.abortJobs(pendingJobs);
        return this.scheduleNewJob();
    }
}