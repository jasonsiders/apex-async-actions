/**
 * @description Exposes initAction logic to Flow callers.
 * This allows flows to generate async actions that respect current AsyncActionProcessor__mdt settings.
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global class InvocableInitAsyncAction {
	/**
	 * @description Initializes async actions based on processor settings and input data.
	 * @param inputs List of Input objects containing processor configuration and action data
	 * @return List of initialized AsyncAction__c records
	 */
	@InvocableMethod(category='Async Actions' label='Init Async Action')
	global static List<AsyncAction__c> invoke(List<InvocableInitAsyncAction.Input> inputs) {
		List<AsyncAction__c> actions = new List<AsyncAction__c>{};
		for (InvocableInitAsyncAction.Input input : inputs) {
			AsyncAction__c action = input?.initAction();
			actions?.add(action);
		}
		return actions;
	}

	// **** INNER **** //
	/**
	 * @description Input wrapper class for the InvocableInitAsyncAction.invoke method.
	 * Contains all necessary information to initialize an async action.
	 */
	global class Input {
		/**
		 * @description Developer name of the AsyncActionProcessor__mdt record to use for this action.
		 */
		@InvocableVariable(label='AsyncActionProcessor__mdt DeveloperName' required=true)
		global String developerName;

		/**
		 * @description Optional data payload for the async action.
		 */
		@InvocableVariable(label='Data')
		global String data;

		/**
		 * @description Optional ID of the record this async action is related to.
		 */
		@InvocableVariable(label='Related Record ID')
		global Id relatedRecordId;

		private AsyncAction__c initAction() {
			AsyncActionProcessor__mdt settings = this.getSettings();
			return AsyncActions.initAction(settings, this.relatedRecordId, this.data);
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
