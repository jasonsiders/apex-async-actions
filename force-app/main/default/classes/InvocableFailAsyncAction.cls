/**
 * @description Exposes AsyncActions.Failure logic to Flow callers.
 * Flow callers should use this invocable when an async action fails,
 * but they want the details of how that failure is handled to respect the current retry configuration.
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global class InvocableFailAsyncAction {
	private static final AsyncActions.RetryBehavior DEFAULT_BEHAVIOR = AsyncActions.RetryBehavior.ALLOW_RETRY;

	/**
	 * @description Processes failure handling for async actions according to their retry configuration.
	 * @param inputs List of Input objects containing action details and error information
	 */
	@InvocableMethod(category='Async Actions' label='Handle Async Action Failures')
	global static void invoke(List<InvocableFailAsyncAction.Input> inputs) {
		// Run the failure logic for each of the inputs
		// This will result in the Status and/or Retries being updated **in memory**
		for (InvocableFailAsyncAction.Input input : inputs) {
			input?.fail();
		}
	}

	/**
	 * @description Input wrapper class for the InvocableFailAsyncAction.invoke method.
	 * Contains all necessary information to properly handle async action failures.
	 */
	global class Input {
		/**
		 * @description The AsyncAction__c record that failed and needs failure handling.
		 */
		@InvocableVariable(label='AsyncAction__c Record' required=true)
		global AsyncAction__c action;

		/**
		 * @description Developer name of the AsyncActionProcessor__mdt record that defines the retry behavior.
		 */
		@InvocableVariable(label='AsyncActionProcessor__mdt DeveloperName' required=true)
		global String developerName;

		/**
		 * @description Error message describing what went wrong during action processing.
		 */
		@InvocableVariable(label='Error Message' required=true)
		global String errorMessage;

		/**
		 * @description Name of the retry behavior to use. Valid values: ALLOW_RETRY (default), KEEP_ALIVE, SUDDEN_DEATH.
		 */
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
