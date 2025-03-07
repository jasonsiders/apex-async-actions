@SuppressWarnings('PMD.ApexDoc')
public virtual without sharing class AsyncActionJob implements System.Queueable, System.Finalizer {
	private Set<Id> actionIds;
	private AsyncActionProcessor processor;
	private AsyncActionProcessor__mdt settings;
	@TestVisible
	private static Boolean allowRecursion = !Test.isRunningTest();
	private static final Integer ERROR_FIELD_LENGTH = AsyncAction__c.Error__c.getDescribe()?.getLength();

	public AsyncActionJob(AsyncActionProcessor__mdt settings) {
		this.processor = (AsyncActionProcessor) Type.forName(settings?.Processor__c)?.newInstance();
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
			if (error instanceof System.AsyncException && this.settings?.BypassFinalizerRetryLimit__c == true) {
				// Note: Finalizers can only re-enqueue failed jobs a max of 5 times in a row.
				// If this happens, a System.AsyncException will be thrown to prevent runaway jobs.
				// Our finalizer handles failed jobs by marking actions as failed, so we don't need to worry about this.
				// Re-launch the job via a platform event, this resets the stack depth to 0
				String msg = 'Could not re-launch during finalizer. Re-launching via platform event.\n' + error;
				AsyncActionLogger.log(System.LoggingLevel.FINEST, msg);
				String actionName = this.settings?.DeveloperName;
				AsyncActionStart__e event = new AsyncActionStart__e(Actions__c = actionName);
				EventBus.publish(event);
			} else {
				String msg = 'Aborting job after error during Finalizer: ' + error;
				AsyncActionLogger.log(System.LoggingLevel.FINEST, msg);
			}
		} finally {
			AsyncActionLogger.save();
		}
	}

	// **** STATIC **** //
	public static AsyncAction__c initAction(AsyncActionProcessor__mdt settings, Id relatedRecordId, String data) {
		// Returns a new action related to the current processor type
		return new AsyncAction__c(
			Data__c = data,
			ProcessorName__c = settings?.DeveloperName,
			RelatedRecordId__c = relatedRecordId,
			Retries__c = settings?.Retries__c ?? 0,
			NextEligibleAt__c = DateTime.now(),
			Status__c = Status.PENDING.name()
		);
	}

	public static AsyncAction__c initAction(AsyncActionProcessor__mdt settings, SObject record, String data) {
		return AsyncActionJob.initAction(settings, record?.Id, data);
	}

	public static AsyncAction__c initAction(AsyncActionProcessor__mdt settings, Id relatedRecordId) {
		return AsyncActionJob.initAction(settings, relatedRecordId, null);
	}

	public static AsyncAction__c initAction(AsyncActionProcessor__mdt settings, SObject record) {
		return AsyncActionJob.initAction(settings, record?.Id);
	}

	public static AsyncAction__c initAction(AsyncActionProcessor__mdt settings) {
		Id nullRecordId = null;
		return AsyncActionJob.initAction(settings, nullRecordId);
	}

	// **** PRIVATE **** //
	@TestVisible
	private virtual void finalize(System.FinalizerContext context) {
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
				AND Status__c = :Status.PENDING.name()
			WITH SYSTEM_MODE
			ORDER BY NextEligibleAt__c ASC
			LIMIT :this.getBatchSize()
		];
		this.actionIds = new Map<Id, AsyncAction__c>(actions)?.keySet();
		return actions;
	}

	private void handleFinalizerError(Exception error) {
		List<AsyncAction__c> actions = this.requeryActions();
		new ErrorHandler(this.settings)?.fail(actions, error);
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

	// **** INNER **** //
	public class ErrorHandler {
		private AsyncActionJob.RetryBehavior behavior;
		private AsyncActionProcessor__mdt settings;

		public ErrorHandler(AsyncActionProcessor__mdt settings, AsyncActionJob.RetryBehavior behavior) {
			this.behavior = behavior;
			this.settings = settings;
		}

		public ErrorHandler(AsyncActionProcessor__mdt settings) {
			this(settings, AsyncActionJob.RetryBehavior.ALLOW_RETRY);
		}

		public void fail(List<AsyncAction__c> actions, Object errorObj) {
			for (AsyncAction__c action : actions) {
				// Callers can use this method to handle a failed action
				action.Error__c = String.valueOf(errorObj)?.abbreviate(ERROR_FIELD_LENGTH);
				if (behavior == RetryBehavior.ALLOW_RETRY && this.hasRetries(action)) {
					// Retry the action at some point in the future. Decrement the number of retries.
					action.Retries__c--;
					this.deferProcessing(action);
				} else if (behavior == RetryBehavior.KEEP_ALIVE) {
					// Retry the action at some point in the future. Do not decrement the number of retries.
					this.deferProcessing(action);
				} else {
					// If no retries remain, or if SUDDEN_DEATH, mark the record as failed
					action.Status__c = Status.FAILED.name();
				}
				String msg = String.format(
					'Async Action failed: {0}\nNew Status: {1}. Num Retries: {2}',
					new List<String>{ String.valueOf(errorObj), action?.Status__c, String.valueOf(action?.Retries__c) }
				);
				AsyncActionLogger.log(System.LoggingLevel.ERROR, msg);
			}
		}

		public void fail(AsyncAction__c action, Object errorObj) {
			this.fail(new List<AsyncAction__c>{ action }, errorObj);
		}

		private Boolean hasRetries(AsyncAction__c action) {
			Decimal numRetries = action?.Retries__c ?? 0;
			return numRetries > 0;
		}

		private void deferProcessing(AsyncAction__c action) {
			// Push out the current action so that it won't be eligible
			// for processing until N minutes in the future,
			// as defined by the current settings' Retry Interval
			Integer interval = this.settings?.RetryInterval__c?.intValue() ?? 5;
			action.NextEligibleAt__c = DateTime.now()?.addMinutes(interval);
		}
	}

	public enum RetryBehavior {
		ALLOW_RETRY,
		KEEP_ALIVE,
		SUDDEN_DEATH
	}

	@SuppressWarnings('PMD.FieldNamingConventions')
	public enum Status {
		// Represents the AsyncAction__c.Status__c picklist, offers some type-safety
		// Note: Since picklists are case-sensitive, casing differs from typical enum values
		Pending,
		Completed,
		Failed,
		Canceled
	}
}
