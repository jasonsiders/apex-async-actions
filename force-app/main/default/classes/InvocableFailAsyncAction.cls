@SuppressWarnings('PMD.AvoidGlobalModifier')
global class InvocableFailAsyncAction {
	/**
	 * This class exposes `AsyncActions.Failure` logic to flows
	 * Flow callers should use this invocable when an async action fails,
	 * but they want the details of how that failure is handled to respect the current retry configuration
	 **/
	private static final AsyncActions.RetryBehavior DEFAULT_BEHAVIOR = AsyncActions.RetryBehavior.ALLOW_RETRY;

	@InvocableMethod(category='Async Actions' label='Handle Async Action Failures')
	global static void invoke(List<InvocableFailAsyncAction.Input> inputs) {
		// Run the failure logic for each of the inputs
		// This will result in the Status and/or Retries being updated **in memory**
		for (InvocableFailAsyncAction.Input input : inputs) {
			input?.fail();
		}
	}

	global class Input {
		@InvocableVariable(label='AsyncAction__c Record' required=true)
		global AsyncAction__c action;

		@InvocableVariable(label='AsyncActionProcessor__mdt DeveloperName' required=true)
		global String developerName;

		@InvocableVariable(label='Error Message' required=true)
		global String errorMessage;

		@InvocableVariable(
			label='Retry Behavior'
			description='Allowed Values: ["ALLOW_RETRY" (default), "KEEP_ALIVE", "SUDDEN_DEATH"]'
		)
		global String retryBehaviorName = DEFAULT_BEHAVIOR?.name();

		private void fail() {
			AsyncActionProcessor__mdt settings = this.getSettings();
			AsyncActions.RetryBehavior behavior = this.getRetryBehavior();
			new AsyncActions.Failure(settings, behavior)?.fail(this.action, this.errorMessage);
		}

		private AsyncActions.RetryBehavior getRetryBehavior() {
			try {
				return AsyncActions.RetryBehavior.valueOf(this.retryBehaviorName);
			} catch (System.NoSuchElementException error) {
				return DEFAULT_BEHAVIOR;
			}
		}

		private AsyncActionProcessor__mdt getSettings() {
			AsyncActionProcessor__mdt settings = AsyncActionProcessorService.get(this.developerName);
			if (settings == null) {
				String msg = this.developerName + ' is not a valid AsyncActionProcessor__mdt';
				throw new System.IllegalArgumentException(msg);
			}
			return settings;
		}
	}
}
