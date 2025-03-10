public class AsyncActionFlowProcessor implements AsyncActions.Processor {
	@TestVisible
	private static String actionParameter = 'asyncAction';
	private static String settingsParameter = 'settings';

	public AsyncActionFlowProcessor(AsyncActionProcessor__mdt settings) {
		AsyncActionFlowProcessor.validateFlowExists(settings);
	}

	public void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
		// Re-validate that the flow exists; to guard against flows deleted during an ongoing job
		AsyncActionFlowProcessor.validateFlowExists(settings);
		// Run the flow logic with the current settings & action records
		new FlowContainer(settings, actions)?.runFlow();
	}

	private static void validateFlowExists(AsyncActionProcessor__mdt settings) {
		// Note: The Invocable.Actions class will fail silently if an invalid flow name is given
		// To prevent this, use the Flow.Interview class to check if the flow exists
		// if the flow does not exist, a System.TypeException will be thrown
		String flowName = settings?.Processor__c;
		Flow.Interview.createInterview(flowName, new Map<String, Object>{});
	}

	private static void validateIsSuccess(Invocable.Action.Result result) {
		// Throw an exception if the provided invocable failed for any reason
		if (result?.isSuccess() == false) {
			String msg = result?.getErrors()?.get(0)?.getMessage();
			throw new System.FlowException(msg);
		}
	}

	@TestVisible
	private static void validateOutputParams(Invocable.Action.Result result) {
		// Throw an exception if the provided invocable doesn't expose an AsyncAction__c record as an output
		if (result?.getOutputParameters()?.containsKey(actionParameter) == false) {
			throw new System.FlowException('Missing required output parameter: ' + actionParameter);
		}
	}

	// **** INNER **** //
	private class FlowContainer {
		private List<AsyncAction__c> actions;
		private Invocable.Action flow;
		private AsyncActionProcessor__mdt settings;

		public FlowContainer(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
			this.settings = settings;
			this.actions = actions;
			this.flow = Invocable.Action.createCustomAction('flow', settings?.Processor__c);
			this.addInvocationsToFlow();
		}

		public void runFlow() {
			// Invoke the flow, and handle its results
			List<Invocable.Action.Result> results = this.flow?.invoke();
			for (Integer i = 0; i < results?.size(); i++) {
				Invocable.Action.Result result = results?.get(i);
				AsyncAction__c action = this.actions?.get(i);
				this.handleResult(result, action);
			}
		}

		private void addInvocationsToFlow() {
			// The Invocable.Actions class uses flow bulkification logic
			// Each action is processed via their own "Invocation", with their own inputs/outputs
			// DML, SOQL, and other actions are automatically bulkified in this context
			// This method builds a single invocation for each Async Action method
			for (AsyncAction__c action : actions) {
				Invocable.Action invocation = this.flow?.addInvocation();
				invocation?.setInvocationParameter(actionParameter, action);
				invocation?.setInvocationParameter(settingsParameter, settings);
			}
		}

		@TestVisible
		private void handleResult(Invocable.Action.Result result, AsyncAction__c action) {
			// The AsyncActionJob will udpate in-memory AsyncAction__c records at the end of each transaction
			// Update these records with updated values from the flow
			try {
				AsyncActionFlowProcessor.validateIsSuccess(result);
				AsyncActionFlowProcessor.validateOutputParams(result);
				this.updateActionFields(result, action);
			} catch (Exception error) {
				// Mark the current action as failed, according to the currently defined retry behavior
				new AsyncActions.Failure(this.settings)?.fail(action, error);
			}
		}

		private void updateActionFields(Invocable.Action.Result result, AsyncAction__c original) {
			// Get updated action values, and update the in-memory AsyncAction__c record
			// Note: Must update each field individually, since we can't reassign the in-memory pointer
			AsyncAction__c updated = (AsyncAction__c) result?.getOutputParameters()?.get(actionParameter);
			for (
				SObjectField field : new List<SObjectField>{
					AsyncAction__c.Error__c,
					AsyncAction__c.NextEligibleAt__c,
					AsyncAction__c.Retries__c,
					AsyncAction__c.Status__c
				}
			) {
				Object newValue = updated?.get(field);
				original?.put(field, newValue);
			}
		}
	}
}
