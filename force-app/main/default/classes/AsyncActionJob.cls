/**
 * @description Responsible for processing Async Actions via a Queueable job.
 * The actual logic of each action is handled by the `AsyncActions.Processor` interface.
 */
public virtual without sharing class AsyncActionJob implements Database.AllowsCallouts, System.Queueable, System.Finalizer {
	@TestVisible
	private static Boolean allowRecursion = !Test.isRunningTest();

	/** @description Ids of the actions this job locked; the finalizer re-queries them, since only Ids survive to it **/
	@TestVisible
	private Set<Id> actionIds;
	private Boolean isLockedOut;
	private AsyncActions.Processor processor;
	private AsyncActionProcessor__mdt settings;

	/**
	 * @description Constructs an AsyncActionJob using the provided factory.
	 * This class can't be manually instantiated; instead use the AsyncActionLauncher class to launch a job.
	 * @param factory The factory containing processor settings for this job
	 */
	public AsyncActionJob(AsyncActionLauncher.Factory factory) {
		this.settings = factory?.getSettings();
		this.initializeProcessor(settings);
	}

	// **** QUEUEABLE **** //
	/**
	 * @description Executes the queueable job, processing pending async actions for the configured processor.
	 * @param context The queueable context provided by the platform
	 */
	public void execute(System.QueueableContext context) {
		System.attachFinalizer(this);
		if (this.settings?.Enabled__c == true) {
			try {
				List<AsyncAction__c> actions = this.queryPendingActions();
				// Empty when another job got to these actions first
				if (actions?.isEmpty() == false) {
					this.processor?.process(this.settings, actions);
					Database.update(actions, false, System.AccessLevel.SYSTEM_MODE);
				}
			} catch (Exception error) {
				AsyncActionLogger.log(System.LoggingLevel.ERROR, error);
				throw error;
			} finally {
				AsyncActionLogger.save();
			}
		}
	}

	// **** FINALIZER **** //
	/**
	 * @description Executes the finalizer, handling cleanup and error recovery after the queueable job completes.
	 * Note: Finalizers run in their own execution context, after the Queueable job finishes.
	 * Its execution does not count towards the async method limit.
	 * Read More: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_transaction_finalizers.htm
	 * @param context The finalizer context provided by the platform
	 */
	public void execute(System.FinalizerContext context) {
		try {
			this.finalize(context);
		} catch (Exception error) {
			String msg = 'Aborting job after error during Finalizer: ' + error;
			AsyncActionLogger.log(System.LoggingLevel.FINEST, msg);
		} finally {
			AsyncActionLogger.save();
		}
	}

	// **** PRIVATE **** //
	/**
	 * @description Handles finalization logic, checking job status and managing failures and recursion.
	 * @param context The finalizer context containing job execution results
	 */
	@TestVisible
	protected virtual void finalize(System.FinalizerContext context) {
		if (context?.getResult() == System.ParentJobResult.UNHANDLED_EXCEPTION) {
			// The job failed; mark each action record as failed, according to its defined retry behavior
			Exception error = context?.getException();
			List<AsyncAction__c> actions = this.requeryActions();
			new AsyncActions.Failure(this.settings)?.fail(actions, error);
			Database.update(actions, true, System.AccessLevel.SYSTEM_MODE);
		}
		// Re-launch this job if there are still pending records
		// A locked out job doesn't; the job holding its actions re-launches when it finishes
		if (this.settings?.Enabled__c == true && this.isLockedOut != true && AsyncActionJob.allowRecursion == true) {
			new AsyncActionLauncher()?.launch(this.settings);
		}
	}

	/**
	 * @description Locks the given actions that are still pending and eligible, until this transaction ends.
	 * A concurrent job locking the same actions waits for this one to finish, then gets only those still pending.
	 * Read More: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/langCon_apex_locking_statements.htm
	 * @param candidates The actions to lock
	 * @return The locked actions
	 */
	protected virtual List<AsyncAction__c> lockPendingActions(List<AsyncAction__c> candidates) {
		return [
			SELECT Id, Data__c, Error__c, NextEligibleAt__c, ProcessorName__c, RelatedRecordId__c, Retries__c, Status__c
			FROM AsyncAction__c
			WHERE
				Id IN :candidates
				AND NextEligibleAt__c <= :DateTime.now()
				AND Status__c = :AsyncActions.Status.PENDING.name()
			WITH SYSTEM_MODE
			FOR UPDATE
		];
	}

	private Integer getBatchSize() {
		return this.settings?.BatchSize__c?.intValue() ?? 200;
	}

	private void initializeProcessor(AsyncActionProcessor__mdt settings) {
		if (settings?.ProcessorType__c == 'Flow') {
			this.processor = new AsyncActionFlowProcessor(settings);
		} else {
			this.processor = (AsyncActions.Processor) Type.forName(settings?.Processor__c)?.newInstance();
		}
	}

	/**
	 * @description Claims the next batch, so no other job processes the same actions while this one runs
	 * @return The actions this job processes; empty if another job holds them
	 */
	private List<AsyncAction__c> queryPendingActions() {
		List<AsyncAction__c> oldest = this.queryOldestPendingActions();
		List<AsyncAction__c> actions = this.tryLockPendingActions(oldest);
		this.actionIds = new Map<Id, AsyncAction__c>(actions)?.keySet();
		return actions;
	}

	/**
	 * @description Selects the next batch of pending actions for the current processor, first in first out.
	 * Locking queries can't use ORDER BY, so the batch is picked here and locked separately.
	 * @return The oldest pending actions, up to the processor's batch size (Ids only)
	 */
	private List<AsyncAction__c> queryOldestPendingActions() {
		String processorName = this.settings?.DeveloperName;
		return [
			SELECT Id
			FROM AsyncAction__c
			WHERE
				ProcessorName__c = :processorName
				AND NextEligibleAt__c <= :DateTime.now()
				AND Status__c = :AsyncActions.Status.PENDING.name()
			WITH SYSTEM_MODE
			ORDER BY NextEligibleAt__c ASC // First in, first out!
			LIMIT :this.getBatchSize()
		];
	}

	/**
	 * @description Re-selects this job's still-pending actions, so its failure skips actions another job handled
	 * @return The actions to mark as failed
	 */
	private List<AsyncAction__c> requeryActions() {
		// Note: SObject lists persist from Queueable to Finalizer, but in a truncated form (only Ids retained)
		// Necessary to re-query to avoid "SObject row retrieved via SOQL" errors
		// Once this job's work rolled back, a job waiting on its locks may have processed these actions; skip those
		return [
			SELECT Id, Data__c, Retries__c, ProcessorName__c, RelatedRecordId__c, NextEligibleAt__c, Status__c
			FROM AsyncAction__c
			WHERE
				Id IN :this.actionIds
				AND NextEligibleAt__c <= :DateTime.now()
				AND Status__c = :AsyncActions.Status.PENDING.name()
			WITH SYSTEM_MODE
			FOR UPDATE
		];
	}

	/**
	 * @description Locks the given actions; if another job holds them past the lock wait, locks none.
	 * @param candidates The actions to lock
	 * @return The locked actions, or an empty list if another job holds them
	 */
	private List<AsyncAction__c> tryLockPendingActions(List<AsyncAction__c> candidates) {
		try {
			return this.lockPendingActions(candidates);
		} catch (System.QueryException error) {
			this.isLockedOut = true;
			String msg = this.settings?.DeveloperName + ': actions locked by another job; skipping. ' + error;
			AsyncActionLogger.log(System.LoggingLevel.FINEST, msg);
			return new List<AsyncAction__c>{};
		}
	}
}
