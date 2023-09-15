global abstract class AsyncActionProcessor implements apxsp.TypeAware, System.Queueable, System.Finalizer {
    global static Boolean allowRecursion = !Test.isRunningTest();
    protected AsyncActionProcessor__mdt config = this.getProcessorSettings();
    protected Set<Id> actionIds;
    
    // **** ABSTRACT **** // 
    global abstract Type getType(); 
    global abstract void process(List<AsyncAction__c> actions); 
    
    // **** QUEUEABLE **** // 
    global void execute(System.QueueableContext context) {
        if (this.config?.Enabled__c == true) {
            System.attachFinalizer(this);
            List<AsyncAction__c> actions = this.getPendingActions();
            this.actionIds = new Map<Id, AsyncAction__c>(actions)?.keySet();
            this.process(actions); 
            apxsp.Logger.publish();
        }
    }

    // **** FINALIZER **** // 
    global void execute(System.FinalizerContext context) {
        // Note: Finalizers run in their own execution context, after the Queueable job finishes.
		// Its execution does not count towards the async method limit.
		// Read More: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_transaction_finalizers.htm
		// * Check the current job status, and handle any unexpected failures
        if (context?.getResult() == System.ParentJobResult.UNHANDLED_EXCEPTION) {
			List<AsyncAction__c> actions = this.requeryActions();  
			this.fail(actions, RetryBehavior.ALLOW_RETRY, context?.getException());
            update actions; 
		}
        // * Re-launch if still pending
		if (AsyncActionProcessor.allowRecursion == true) {
            Id currentJobId = context?.getAsyncApexJobId();
            AsyncActionLauncher.launchJobs(this.config, currentJobId);
        }
        // * Commit any logs accrued during the finalizer context
		apxsp.Logger.publish();
    }

    // **** PUBLIC **** //
    global void fail(List<AsyncAction__c> actions, RetryBehavior behavior, Object errorObj) {
        // TODO! implement the differing retry behaviors
        // Callers can use this method to handle failed actions.
		// Decrement Retries__c if available. Else, mark the action as "Failed".
		for (AsyncAction__c action : actions) {
			if (action?.Retries__c > 0) {
				// Retry the action at some point in the future
                Integer interval = this.getRetryInterval();
                action.Scheduled__c = DateTime.now()?.addMinutes(interval);
                action.Retries__c--;
			} else {
				// No more retries remaining. Mark the action as failed
				action.Status__c = 'Failed';
			}
			String msg = 'Async Action failed: ' + errorObj + '\nNew Status: ' + action?.Status__c + '. Num Retries: ' + action?.Retries__c;
            Type currentType = this.getType();
			apxsp.Logger.Options options = new apxsp.Logger.Options()?.setApexClass(currentType)?.setRecordId(action?.Id)?.setSource(AsyncActionConstants.PACKAGE_NAME);
			apxsp.Logger.error(msg, options); 
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
        return this.config?.Enabled__c == true;
    }

    // **** PRIVATE **** //
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
			WHERE 
                ProcessorClass__c = :typeName 
                AND Scheduled__c <= :DateTime.now() 
                AND Status__c = :Status.PENDING.name()
			ORDER BY Scheduled__c ASC
			LIMIT :this.getBatchSize()
		];
    }

    private AsyncActionProcessor__mdt getProcessorSettings() {
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
    global enum RetryBehavior {
        ALLOW_RETRY,
        KEEP_ALIVE,
        SUDDEN_DEATH
    }

    global enum Status {
        // Represents the AsyncAction__c.Status__c picklist, offers some type-safety
        Pending, 
        Completed,
        Failed,
        Canceled
    }
}