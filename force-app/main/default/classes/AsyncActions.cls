/**
 * @description Central namespace providing core types and methods for asynchronous action processing.
 * This class acts as a pseudo-namespace, providing a central location for all global types and methods,
 * with the exception of the built-in logging framework.
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global abstract class AsyncActions {
	private static final Integer ERROR_FIELD_LENGTH = AsyncAction__c.Error__c.getDescribe()?.getLength();

	// **** STATIC **** //
	/**
	 * @description Initializes a new AsyncAction__c record with the specified processor settings, related record ID, and data.
	 * @param settings The processor configuration metadata to use for initializing the action
	 * @param relatedRecordId The ID of the record this action is related to
	 * @param data String data to be processed by the action
	 * @return A new AsyncAction__c record configured with the provided parameters
	 */
	global static AsyncAction__c initAction(AsyncActionProcessor__mdt settings, Id relatedRecordId, String data) {
		return new AsyncAction__c(
			Data__c = data,
			ProcessorName__c = settings?.DeveloperName,
			RelatedRecordId__c = relatedRecordId,
			Retries__c = settings?.Retries__c ?? 0,
			NextEligibleAt__c = DateTime.now(),
			Status__c = AsyncActions.Status.PENDING.name()
		);
	}

	/**
	 * @description Initializes a new AsyncAction__c record with the specified processor settings, SObject record, and data.
	 * @param settings The processor configuration metadata to use for initializing the action
	 * @param record The SObject record this action is related to
	 * @param data String data to be processed by the action
	 * @return A new AsyncAction__c record configured with the provided parameters
	 */
	global static AsyncAction__c initAction(AsyncActionProcessor__mdt settings, SObject record, String data) {
		return AsyncActions.initAction(settings, record?.Id, data);
	}

	/**
	 * @description Initializes a new AsyncAction__c record with the specified processor settings and related record ID.
	 * @param settings The processor configuration metadata to use for initializing the action
	 * @param relatedRecordId The ID of the record this action is related to
	 * @return A new AsyncAction__c record configured with the provided parameters
	 */
	global static AsyncAction__c initAction(AsyncActionProcessor__mdt settings, Id relatedRecordId) {
		return AsyncActions.initAction(settings, relatedRecordId, null);
	}

	/**
	 * @description Initializes a new AsyncAction__c record with the specified processor settings and SObject record.
	 * @param settings The processor configuration metadata to use for initializing the action
	 * @param record The SObject record this action is related to
	 * @return A new AsyncAction__c record configured with the provided parameters
	 */
	global static AsyncAction__c initAction(AsyncActionProcessor__mdt settings, SObject record) {
		return AsyncActions.initAction(settings, record?.Id);
	}

	/**
	 * @description Initializes a new AsyncAction__c record with the specified processor settings and no related record.
	 * @param settings The processor configuration metadata to use for initializing the action
	 * @return A new AsyncAction__c record configured with the provided parameters
	 */
	global static AsyncAction__c initAction(AsyncActionProcessor__mdt settings) {
		Id nullRecordId = null;
		return AsyncActions.initAction(settings, nullRecordId);
	}

	// **** INNER **** //
	/**
	 * @description Handles failure scenarios for async actions, implementing retry logic and error handling.
	 */
	global class Failure {
		private AsyncActions.RetryBehavior behavior;
		private AsyncActionProcessor__mdt settings;

		/**
		 * @description Constructs a Failure handler with specific processor settings and retry behavior.
		 * @param settings The processor configuration metadata
		 * @param behavior The retry behavior to apply when handling failures
		 */
		global Failure(AsyncActionProcessor__mdt settings, AsyncActions.RetryBehavior behavior) {
			this.behavior = behavior;
			this.settings = settings;
		}

		/**
		 * @description Constructs a Failure handler with specific processor settings and default ALLOW_RETRY behavior.
		 * @param settings The processor configuration metadata
		 */
		global Failure(AsyncActionProcessor__mdt settings) {
			this(settings, AsyncActions.RetryBehavior.ALLOW_RETRY);
		}

		/**
		 * @description Handles failure for a list of async actions, applying retry logic based on the configured behavior.
		 * @param actions List of AsyncAction__c records that have failed
		 * @param error The error object that caused the failure
		 */
		global void fail(List<AsyncAction__c> actions, Object error) {
			for (AsyncAction__c action : actions) {
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

		/**
		 * @description Handles failure for a single async action, applying retry logic based on the configured behavior.
		 * @param action The AsyncAction__c record that has failed
		 * @param error The error object that caused the failure
		 */
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

	/**
	 * @description Interface defining the logic to be performed in an Async Action.
	 * Create a class that implements this interface,
	 * and list the fully qualified api name of that class in AsyncActionProcessor__mdt.Processor__c
	 */
	global interface Processor {
		/**
		 * @description Processes a list of async actions according to the specified processor settings.
		 * @param settings The processor configuration metadata that defines how to process the actions
		 * @param actions List of AsyncAction__c records to be processed
		 */
		void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions);
	}

	/**
	 * @description Enumeration defining retry behaviors for failed async actions.
	 */
	global enum RetryBehavior {
		ALLOW_RETRY,
		KEEP_ALIVE,
		SUDDEN_DEATH
	}

	/**
	 * @description Enumeration representing the AsyncAction__c.Status__c picklist, offering type-safety.
	 * Note: Since picklists are case-sensitive, casing differs from typical enum values
	 */
	@SuppressWarnings('PMD.FieldNamingConventions')
	global enum Status {
		Pending,
		Completed,
		Failed,
		Canceled
	}
}
