global abstract class AsyncActionProcessor implements apxsp.TypeAware, System.Queueable, System.Finalizer {
    global static Boolean allowRecursion = !Test.isRunningTest();
    protected AsyncActionProcessor__mdt config = this.getProcessorConfig();
    protected AsyncActionSetting__mdt settings = AsyncActionSettingService.getSettings(); 
    protected Set<Id> actionIds;
    
    // **** ABSTRACT **** // 
    global abstract Type getType(); 
    global abstract void process(List<AsyncAction__c> actions); 
    
    // **** QUEUEABLE **** // 
    global void execute(System.QueueableContext context) {
        System.attachFinalizer(this);
        List<AsyncAction__c> actions = this.getPendingActions();
        this.actionIds = new Map<Id, AsyncAction__c>(actions)?.keySet();
        this.process(actions); 
        apxsp.Logger.publish();
    }

    // **** FINALIZER **** // 
    global void execute(System.FinalizerContext context) {
        // Note: Finalizers run in their own execution context, after the Queueable job finishes.
		// Its execution does not count towards the async method limit.
		// Read More: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_transaction_finalizers.htm
		// * Check the current job status, and handle any unexpected failures
        if (context?.getResult() == System.ParentJobResult.UNHANDLED_EXCEPTION) {
			List<AsyncAction__c> actions = this.requeryActions();  
			this.fail(actions, context?.getException());
            update actions; 
		}
        // * Re-launch if still pending
		if (AsyncActionProcessor.allowRecursion == true) {
            Id currentJobId = context?.getAsyncApexJobId();
            Id newJobId = this.launch(currentJobId);
        }
        // * Commit any logs accrued during the finalizer context
		apxsp.Logger.publish();
    }

    // **** PUBLIC **** //
    global void fail(List<AsyncAction__c> actions, Object errorObj) {
        // Callers can use this method to handle failed actions.
		// Decrement Retries__c if available. Else, mark the action as "Failed".
		for (AsyncAction__c action : actions) {
			if (action?.Retries__c > 0) {
				// Retry the action at some point in the future
				action.Retries__c--;
                action.Scheduled__c = DateTime.now()?.addMinutes(this.getRetryInterval());
			} else {
				// No more retries remaining. Mark the action as failed
				action.Status__c = 'Failed';
			}
			String msg = 'Async Action failed: ' + errorObj + '\nNew Status: ' + action?.Status__c + '. Num Retries: ' + action?.Retries__c;
			apxsp.Logger.AdvancedOptions options = new apxsp.Logger.AdvancedOptions()?.setRecordId(action?.Id)?.setSource(this.getType());
			apxsp.Logger.error(options, msg); 
		}
    }

    global AsyncAction__c initAction(Id relatedRecordId, String data) {
        // Returns a new action related to the current processor type 
        return new AsyncAction__c(
            Data__c = data,
            ProcessorClass__c = this.getType()?.getName(),
            RelatedRecordId__c = relatedRecordId,
            Retries__c = this.config?.Retries__c, 
            Scheduled__c = DateTime.now(),
            Status__c = Status.PENDING.name()
        ); 
    }
    
    global AsyncAction__c initAction(Id relatedRecordId) {
        return this.initAction(relatedRecordId, null); 
    }

    global Boolean isEnabled() {
        return this.canRunQueueable() && this.config?.Enabled__c == true; 
    }

    global Id launch(Id currentJobId) {
        // Launches a new instance of the current job if enabled, if not already running, and if it has pending actions
		// This exists to prevent unnecessary/duplicate jobs from running
        List<AsyncActionProcessor__mdt> configs = new List<AsyncActionProcessor__mdt>{this.config};
		return AsyncActionLauncher.launchJobs(configs, currentJobId)?.get(this.getType());
    }

    global Id launch() {
        // Use this overload when outside of a queueable context
        return this.launch(null);
    }

    // **** PRIVATE **** //
    private Boolean canRunQueueable() {
        return Limits.getQueueableJobs() < Limits.getLimitQueueableJobs();
    }

    private Integer getBatchSize() {
        Integer batchSize = this.config?.BatchSize__c?.intValue();
        return (batchSize != null) ? batchSize : 200; 
    }

    private Integer getRetryInterval() {
        Integer interval = this.config?.RetryInterval__c?.intValue();
        return (interval != null) ? interval : 5;
    }

    private List<AsyncAction__c> getPendingActions() {
        final String typeName = this.getType()?.getName();
        return [
			SELECT Id, Data__c, Retries__c, ProcessorClass__c, RelatedRecordId__c, Scheduled__c, Status__c
			FROM AsyncAction__c
			WHERE ProcessorClass__c = :typeName AND Scheduled__c <= :DateTime.now() AND Status__c = 'Pending'
			ORDER BY Scheduled__c ASC
			LIMIT :this.getBatchSize()
		];
    }

    private AsyncActionProcessor__mdt getProcessorConfig() {
        String processorName = this.getType()?.getName(); 
        return AsyncActionProcessorService.get(processorName);
    }

    private List<AsyncAction__c> requeryActions() {
		// Note: SObject lists persist from Queueable to Finalizer, but in a truncated form (only Ids retained)
		// Necessary to re-query to avoid "SObject row retrieved via SOQL" errors
        return [
            SELECT Id, Data__c, Retries__c, ProcessorClass__c, RelatedRecordId__c, Scheduled__c, Status__c 
            FROM AsyncAction__c
            WHERE Id IN :this.actionIds
        ];
    }

    // **** INNER **** // 
    global enum Status {
        // Represents the AsyncAction__c.Status__c picklist, offers some type-safety
        Pending, 
        Completed,
        Failed,
        Canceled
    }
}