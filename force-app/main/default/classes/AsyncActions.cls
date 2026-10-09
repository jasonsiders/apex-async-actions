/**
 * @description Central namespace providing core types and methods for asynchronous action processing.
 * This class acts as a pseudo-namespace, providing a central location for all global types and methods,
 * with the exception of the built-in logging framework.
 */
// CognitiveComplexity sums every inner type into this class's total; no single method scores above 1
@SuppressWarnings('PMD.AvoidGlobalModifier,PMD.CognitiveComplexity')
global abstract class AsyncActions {
	private static final Integer ERROR_FIELD_LENGTH = AsyncAction__c.Error__c.getDescribe()?.getLength();

	// **** STATIC **** //
	/**
	 * @description Groups the actions by the record each one names, so the processor can query each record once and give
	 * every action for that record the same outcome. Fails, without retries, actions that name no valid record or that the
	 * behavior rejects as duplicates, since no retry could fix them.
	 * @param settings The processor configuration metadata
	 * @param actions The actions to group
	 * @param behavior Whether actions that name the same record share an outcome, or all but the first fail
	 * @return Each record's group, keyed by the record's Id
	 */
	global static Map<Id, AsyncActions.RecordGroup> groupByRecord(
		AsyncActionProcessor__mdt settings,
		List<AsyncAction__c> actions,
		AsyncActions.DuplicateBehavior behavior
	) {
		Map<Id, AsyncActions.RecordGroup> groups = new Map<Id, AsyncActions.RecordGroup>{};
		for (AsyncAction__c action : actions) {
			Id recordId = AsyncActions.parseRecordId(action);
			AsyncActions.RecordGroup recordGroup = groups?.get(recordId) ??
				new AsyncActions.RecordGroup(settings, recordId, behavior);
			recordGroup?.add(action);
			groups?.put(recordId, recordGroup);
		}
		// Note: add() fails every action without a valid Id, so the group under the null key is always empty
		groups?.remove(null);
		return groups;
	}

	/**
	 * @description Groups the actions by the record each one names, so that actions naming the same record share an outcome.
	 * @param settings The processor configuration metadata
	 * @param actions The actions to group
	 * @return Each record's group, keyed by the record's Id
	 */
	global static Map<Id, AsyncActions.RecordGroup> groupByRecord(
		AsyncActionProcessor__mdt settings,
		List<AsyncAction__c> actions
	) {
		AsyncActions.DuplicateBehavior behavior = AsyncActions.DuplicateBehavior.GROUP_DUPLICATES;
		return AsyncActions.groupByRecord(settings, actions, behavior);
	}

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
	/**
	 * @description RelatedRecordId__c is a text field, and assigning invalid text to an Id throws.
	 * @param action The action to read
	 * @return The related record Id, or null when the field is blank or not a valid Id
	 */
	private static Id parseRecordId(AsyncAction__c action) {
		Id recordId;
		try {
			recordId = action?.RelatedRecordId__c;
		} catch (System.StringException error) {
			// Blank or malformed text: treated the same as a missing Id
			recordId = null;
		}
		return recordId;
	}

	// **** INNER **** //
	/**
	 * @description Whether groupByRecord lets actions that name the same record share an outcome, or fails all but the first.
	 * Fail duplicates when each action carries its own Data__c, since grouping would treat them as one request.
	 */
	global enum DuplicateBehavior {
		GROUP_DUPLICATES,
		FAIL_DUPLICATES
	}

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
	 * @description A record and every action in the batch that names it, so the processor can give them all one outcome.
	 * Built by AsyncActions.groupByRecord().
	 */
	global class RecordGroup {
		/** @description The actions that name the record **/
		private List<AsyncAction__c> actions;
		/** @description Whether actions that name the same record share an outcome **/
		private AsyncActions.DuplicateBehavior behavior;
		/** @description The record the actions name **/
		private Id recordId;
		/** @description Processor metadata controlling retry behavior **/
		private AsyncActionProcessor__mdt settings;

		/**
		 * @description Starts an empty group for the record.
		 * @param settings The processor configuration metadata
		 * @param recordId The record the actions name
		 * @param behavior Whether actions that name the same record share an outcome, or all but the first fail
		 */
		private RecordGroup(AsyncActionProcessor__mdt settings, Id recordId, AsyncActions.DuplicateBehavior behavior) {
			this.actions = new List<AsyncAction__c>{};
			this.behavior = behavior;
			this.recordId = recordId;
			this.settings = settings;
		}

		/**
		 * @description Cancels every action for the record, as when the record no longer needs processing.
		 */
		global void cancel() {
			this.setStatus(AsyncActions.Status.CANCELED);
		}

		/**
		 * @description Completes every action for the record.
		 */
		global void complete() {
			this.setStatus(AsyncActions.Status.COMPLETED);
		}

		/**
		 * @description Fails every action for the record, which retries per the processor's settings.
		 * @param error The error object that caused the failure
		 */
		global void fail(Object error) {
			new AsyncActions.Failure(this.settings)?.fail(this.actions, error);
		}

		/**
		 * @description Returns a copy, so a caller's remove() cannot drop an action from the group and leave it Pending.
		 * @return The actions that name the record
		 */
		global List<AsyncAction__c> getActions() {
			return this.actions?.clone();
		}

		/**
		 * @description Returns the record the actions name.
		 * @return The related record Id
		 */
		global Id getRecordId() {
			return this.recordId;
		}

		/**
		 * @description Adds a valid action to the group, or fails one that can never succeed.
		 * @param action The action to add
		 */
		private void add(AsyncAction__c action) {
			if (this.recordId == null) {
				this.failWithoutRetry(
					action,
					'RelatedRecordId__c must be a valid record Id: ' + action?.RelatedRecordId__c
				);
			} else if (this.isRejectedDuplicate()) {
				this.failWithoutRetry(action, 'Duplicate action for record ' + this.recordId);
			} else {
				this.actions?.add(action);
			}
		}

		/**
		 * @description Fails an action that no retry could fix.
		 * @param action The action to fail
		 * @param message Why the action cannot succeed
		 */
		private void failWithoutRetry(AsyncAction__c action, String message) {
			AsyncActions.RetryBehavior suddenDeath = AsyncActions.RetryBehavior.SUDDEN_DEATH;
			new AsyncActions.Failure(this.settings, suddenDeath)?.fail(action, message);
		}

		/**
		 * @description Only the first action for a record survives when duplicates fail.
		 * @return Whether the next action should fail as a duplicate
		 */
		private Boolean isRejectedDuplicate() {
			Boolean failsDuplicates = (this.behavior == AsyncActions.DuplicateBehavior.FAIL_DUPLICATES);
			return failsDuplicates && this.actions?.isEmpty() == false;
		}

		/**
		 * @description Records an outcome that needs no failure handling on every action for the record.
		 * @param status The outcome to record
		 */
		private void setStatus(AsyncActions.Status status) {
			for (AsyncAction__c action : this.actions) {
				action.Status__c = status?.name();
			}
		}
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
