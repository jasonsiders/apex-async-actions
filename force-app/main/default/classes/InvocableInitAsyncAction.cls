@SuppressWarnings('PMD.AvoidGlobalModifier')
global class InvocableInitAsyncAction {
	/**
	 * This class exposes `initAction` logic to flow callers
	 * This allows flows to generate async actions that respect current `AsyncActionProcessor__mdt` settings
	 */
	@InvocableMethod(category='Async Actions' label='Init Async Action')
	global static List<AsyncAction__c> invoke(List<InvocableInitAsyncAction.Input> inputs) {
		List<AsyncAction__c> actions = new List<AsyncAction__c>();
		for (InvocableInitAsyncAction.Input input : inputs) {
			AsyncAction__c action = input?.initAction();
			actions?.add(action);
		}
		return actions;
	}

	// **** INNER **** //
	global class Input {
		@InvocableVariable(label='AsyncActionProcessor__mdt DeveloperName' required=true)
		global String developerName;

		@InvocableVariable(label='Data')
		global String data;

		@InvocableVariable(label='Related Record ID')
		global Id relatedRecordId;

		private AsyncAction__c initAction() {
			AsyncActionProcessor__mdt settings = AsyncActionProcessorService.get(this.developerName);
			if (settings != null) {
				return AsyncActions.initAction(settings, this.relatedRecordId, this.data);
			} else {
				String msg = this.developerName + ' is not a valid AsyncActionProcessor__mdt';
				throw new System.IllegalArgumentException(msg);
			}
		}
	}
}
