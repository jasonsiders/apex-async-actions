@SuppressWarnings('PMD.AvoidGlobalModifier')
global class AsyncActionErrorHandler {
	private static final Integer ERROR_FIELD_LENGTH = AsyncAction__c.Error__c.getDescribe()?.getLength();

	private AsyncActionErrorHandler.RetryBehavior behavior;
	private AsyncActionProcessor__mdt settings;

	global AsyncActionErrorHandler(AsyncActionProcessor__mdt settings, AsyncActionErrorHandler.RetryBehavior behavior) {
		this.behavior = behavior;
		this.settings = settings;
	}

	global AsyncActionErrorHandler(AsyncActionProcessor__mdt settings) {
		this(settings, AsyncActionErrorHandler.RetryBehavior.ALLOW_RETRY);
	}

	global void handleError(List<AsyncAction__c> actions, Object error) {
		for (AsyncAction__c action : actions) {
			// Callers can use this method to handle a failed action
			action.Error__c = String.valueOf(error)?.abbreviate(ERROR_FIELD_LENGTH);
			if (behavior == AsyncActionErrorHandler.RetryBehavior.ALLOW_RETRY && this.hasRetries(action)) {
				// Retry the action at some point in the future + decrement the number of retries.
				action.Retries__c--;
				this.deferProcessing(action);
			} else if (behavior == AsyncActionErrorHandler.RetryBehavior.KEEP_ALIVE) {
				// Retry the action at some point in the future; do not decrement the number of retries.
				this.deferProcessing(action);
			} else {
				// If no retries remain, or if SUDDEN_DEATH, mark the record as failed
				action.Status__c = AsyncActions.Status.FAILED.name();
			}
			this.logError(action, error);
		}
	}

	global void handleError(AsyncAction__c action, Object error) {
		this.handleError(new List<AsyncAction__c>{ action }, error);
	}

	// **** PRIVATE **** //
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

	// **** INNER **** //
	global enum RetryBehavior {
		ALLOW_RETRY,
		KEEP_ALIVE,
		SUDDEN_DEATH
	}
}
