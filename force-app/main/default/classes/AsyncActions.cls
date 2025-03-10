@SuppressWarnings('PMD.AvoidGlobalModifier')
global abstract class AsyncActions {
	private static final Integer ERROR_FIELD_LENGTH = AsyncAction__c.Error__c.getDescribe()?.getLength();

	// **** STATIC **** //
	global static AsyncAction__c initAction(AsyncActionProcessor__mdt settings, Id relatedRecordId, String data) {
		// Returns a new action related to the current processor
		return new AsyncAction__c(
			Data__c = data,
			ProcessorName__c = settings?.DeveloperName,
			RelatedRecordId__c = relatedRecordId,
			Retries__c = settings?.Retries__c ?? 0,
			NextEligibleAt__c = DateTime.now(),
			Status__c = AsyncActions.Status.PENDING.name()
		);
	}

	global static AsyncAction__c initAction(AsyncActionProcessor__mdt settings, SObject record, String data) {
		return AsyncActions.initAction(settings, record?.Id, data);
	}

	global static AsyncAction__c initAction(AsyncActionProcessor__mdt settings, Id relatedRecordId) {
		return AsyncActions.initAction(settings, relatedRecordId, null);
	}

	global static AsyncAction__c initAction(AsyncActionProcessor__mdt settings, SObject record) {
		return AsyncActions.initAction(settings, record?.Id);
	}

	global static AsyncAction__c initAction(AsyncActionProcessor__mdt settings) {
		Id nullRecordId = null;
		return AsyncActions.initAction(settings, nullRecordId);
	}

	// **** INNER **** //
	global class Failure {
		private AsyncActions.RetryBehavior behavior;
		private AsyncActionProcessor__mdt settings;

		global Failure(AsyncActionProcessor__mdt settings, AsyncActions.RetryBehavior behavior) {
			this.behavior = behavior;
			this.settings = settings;
		}

		global Failure(AsyncActionProcessor__mdt settings) {
			this(settings, AsyncActions.RetryBehavior.ALLOW_RETRY);
		}

		global void fail(List<AsyncAction__c> actions, Object error) {
			for (AsyncAction__c action : actions) {
				// Callers can use this method to handle a failed action
				action.Error__c = String.valueOf(error)?.abbreviate(ERROR_FIELD_LENGTH);
				if (behavior == AsyncActions.RetryBehavior.ALLOW_RETRY && this.hasRetries(action)) {
					// Retry the action at some point in the future + decrement the number of retries.
					action.Retries__c--;
					this.deferProcessing(action);
				} else if (behavior == AsyncActions.RetryBehavior.KEEP_ALIVE) {
					// Retry the action at some point in the future; do not decrement the number of retries.
					this.deferProcessing(action);
				} else {
					// If no retries remain, or if SUDDEN_DEATH, mark the record as failed
					action.Status__c = AsyncActions.Status.FAILED.name();
				}
				this.logError(action, error);
			}
		}

		global void fail(AsyncAction__c action, Object error) {
			this.fail(new List<AsyncAction__c>{ action }, error);
		}

		private void deferProcessing(AsyncAction__c action) {
			// Push out the current action so that it won't be eligible
			// for processing until N minutes in the future,
			// as defined by the current settings' Retry Interval
			Integer interval = this.settings?.RetryInterval__c?.intValue() ?? 5;
			action.NextEligibleAt__c = DateTime.now()?.addMinutes(interval);
		}

		private Boolean hasRetries(AsyncAction__c action) {
			Decimal numRetries = action?.Retries__c ?? 0;
			return numRetries > 0;
		}

		private void logError(AsyncAction__c action, Object error) {
			String msg = String.format(
				'Async Action failed: {0}\nNew Status: {1}. Num Retries: {2}',
				new List<String>{ String.valueOf(error), action?.Status__c, String.valueOf(action?.Retries__c) }
			);
			AsyncActionLogger.log(System.LoggingLevel.ERROR, msg);
		}
	}

	global interface Processor {
		/**
		 * This interface defines the logic to be performed in an Async Action
		 * Create a class that implements this interface,
		 * and list the fully qualified api name of that class in AsyncActionProcessor__mdt.Processor__c
		 **/
		void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions);
	}

	global enum RetryBehavior {
		ALLOW_RETRY,
		KEEP_ALIVE,
		SUDDEN_DEATH
	}

	@SuppressWarnings('PMD.FieldNamingConventions')
	global enum Status {
		// Represents the AsyncAction__c.Status__c picklist, offers some type-safety
		// Note: Since picklists are case-sensitive, casing differs from typical enum values
		Pending,
		Completed,
		Failed,
		Canceled
	}
}
