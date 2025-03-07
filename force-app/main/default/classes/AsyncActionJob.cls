@SuppressWarnings('PMD.ApexDoc')
public without sharing class AsyncActionJob implements System.Queueable, System.Finalizer {
	private Set<Id> actionIds;
	private AsyncActions.Processor processor;
	private AsyncActionProcessor__mdt settings;
	@TestVisible
	private static Boolean allowRecursion = (Test.isRunningTest() == false);

	public AsyncActionJob(AsyncActionProcessor__mdt settings) {
		this.processor = (AsyncActions.Processor) Type.forName(settings?.Processor__c)?.newInstance();
		this.settings = settings;
	}

	// **** QUEUEABLE **** //
	public void execute(System.QueueableContext context) {
		System.attachFinalizer(this);
		if (this.settings?.Enabled__c == true) {
			try {
				List<AsyncAction__c> actions = this.getPendingActions();
				this.processor?.process(this.settings, actions);
				Database.update(actions, false, System.AccessLevel.SYSTEM_MODE);
			} catch (Exception error) {
				AsyncActionLogger.log(System.LoggingLevel.ERROR, error);
				throw error;
			} finally {
				AsyncActionLogger.save();
			}
		}
	}

	// **** FINALIZER **** //
	public void execute(System.FinalizerContext context) {
		// Note: Finalizers run in their own execution context, after the Queueable job finishes.
		// Its execution does not count towards the async method limit.
		// Read More: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_transaction_finalizers.htm
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
	private void finalize(System.FinalizerContext context) {
		// * Check the current job status, and handle any unexpected failures
		if (context?.getResult() == System.ParentJobResult.UNHANDLED_EXCEPTION) {
			this.handleFinalizerError(context?.getException());
		}
		// * Re-launch this job if there are still pending records
		if (this.settings?.Enabled__c == true && AsyncActionJob.allowRecursion == true) {
			new AsyncActionLauncher()?.launch(this.settings);
		}
	}

	private Integer getBatchSize() {
		return this.settings?.BatchSize__c?.intValue() ?? 200;
	}

	private List<AsyncAction__c> getPendingActions() {
		String processorName = this.settings?.DeveloperName;
		List<AsyncAction__c> actions = [
			SELECT Id, Data__c, Retries__c, ProcessorName__c, RelatedRecordId__c, NextEligibleAt__c, Status__c
			FROM AsyncAction__c
			WHERE
				ProcessorName__c = :processorName
				AND NextEligibleAt__c <= :DateTime.now()
				AND Status__c = :AsyncActions.Status.PENDING.name()
			WITH SYSTEM_MODE
			ORDER BY NextEligibleAt__c ASC
			LIMIT :this.getBatchSize()
		];
		this.actionIds = new Map<Id, AsyncAction__c>(actions)?.keySet();
		return actions;
	}

	private void handleFinalizerError(Exception error) {
		List<AsyncAction__c> actions = this.requeryActions();
		new AsyncActionErrorHandler(this.settings)?.handleError(actions, error);
		Database.update(actions, true, System.AccessLevel.SYSTEM_MODE);
	}

	private List<AsyncAction__c> requeryActions() {
		// Note: SObject lists persist from Queueable to Finalizer, but in a truncated form (only Ids retained)
		// Necessary to re-query to avoid "SObject row retrieved via SOQL" errors
		return [
			SELECT Id, Data__c, Retries__c, ProcessorName__c, RelatedRecordId__c, NextEligibleAt__c, Status__c
			FROM AsyncAction__c
			WHERE Id IN :this.actionIds
			WITH SYSTEM_MODE
		];
	}
}
