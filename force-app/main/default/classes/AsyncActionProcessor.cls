global abstract class AsyncActionProcessor implements System.Queueable, System.Finalizer {
    global Set<Id> actionIds;
    global AsyncActionProcessor__mdt config = AsyncActionProcessorService.get(this.getType()?.getName());
    global Logger logger = new Logger()
        ?.setLoggedFrom(this.getType())
        ?.setSource(AsyncActionConstants.PACKAGE_NAME);
    @TestVisible
    static Boolean allowRecursion = !Test.isRunningTest();
    
    // **** ABSTRACT **** // 
    global abstract Type getType(); 
    global abstract void process(List<AsyncAction__c> actions); 
    
    // **** QUEUEABLE **** // 
    global void execute(System.QueueableContext context) {
        System.attachFinalizer(this);
        if (this.config?.Enabled__c == true) {
            List<AsyncAction__c> actions = this.getPendingActions();
            this.actionIds = new Map<Id, AsyncAction__c>(actions)?.keySet();
            this.process(actions); 
            this.logger?.publish();
        }
    }

    // **** FINALIZER **** // 
    global void execute(System.FinalizerContext context) {
        // Note: Finalizers run in their own execution context, after the Queueable job finishes.
		// Its execution does not count towards the async method limit.
		// Read More: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_transaction_finalizers.htm
        try {
            this.finalize(context);
        } catch (Exception error) {
            this.handleFinalizerError(error);
        }
		this.logger?.publish();
    }

    // **** PUBLIC **** //
    global void fail(AsyncAction__c action, RetryBehavior behavior, Object errorObj) {
        // Callers can use this method to handle a failed action
        if (behavior == RetryBehavior.ALLOW_RETRY && this.hasRetries(action)) {
            // Retry the action at some point in the future. Decrement the number of retries. 
            action.Retries__c--;
            this.reschedule(action);
        } else if (behavior == RetryBehavior.KEEP_ALIVE) {
            // Retry the action at some point in the future. Do not decrement the number of retries. 
            this.reschedule(action);
        } else {
            // If no retries remain, or if SUDDEN_DEATH, mark the record as failed
            action.Status__c = Status.FAILED.name();
        }
        String msg = 'Async Action failed: ' + errorObj + '\nNew Status: ' + action?.Status__c + '. Num Retries: ' + action?.Retries__c;
        this.logger?.clone()?.setRelatedRecordId(action?.Id)?.error(msg);
    }
    
    global void fail(List<AsyncAction__c> actions, RetryBehavior behavior, Object errorObj) {
        // Callers can use this method to handle failed actions in bulk
		for (AsyncAction__c action : actions) {
            this.fail(action, behavior, errorObj);
		}
    }

    global virtual List<AsyncAction__c> getPendingActions() {
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

    global virtual void reschedule(AsyncAction__c action) {
        Integer interval = this.getRetryInterval();
        action.Scheduled__c = DateTime.now()?.addMinutes(interval);
    }

    // **** PRIVATE **** //
    @TestVisible
    private virtual void finalize(System.FinalizerContext context) {
        // * Check the current job status, and handle any unexpected failures
        if (context?.getResult() == System.ParentJobResult.UNHANDLED_EXCEPTION) {
            this.handleFinalizerError(context?.getException());
        }
        // * Re-launch this, and any other jobs - if still pending
        if (this.isEnabled() && AsyncActionProcessor.allowRecursion == true) {
            Id currentJobId = context?.getAsyncApexJobId();
            AsyncActionLauncher.launchAll(currentJobId);
        }
    }

    private Integer getBatchSize() {
        Integer batchSize = this.config?.BatchSize__c?.intValue();
        return (batchSize != null) ? batchSize : 200; 
    }

    private Integer getRetryInterval() {
        Integer interval = this.config?.RetryInterval__c?.intValue();
        return (interval != null) ? interval : 5;
    }

    private void handleFinalizerError(Exception error) {
        List<AsyncAction__c> actions = this.requeryActions();  
        this.fail(actions, RetryBehavior.ALLOW_RETRY, error);
        update actions; 
    }

    private Boolean hasRetries(AsyncAction__c action) {
        Decimal numRetries = (action?.Retries__c != null) ? action?.Retries__c : 0; 
        return numRetries > 0;
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