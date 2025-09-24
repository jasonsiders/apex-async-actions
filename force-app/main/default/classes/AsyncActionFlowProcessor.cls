/**
 * @description Built-in processor class that handles `AsyncActionProcessor__mdt`s with a `ProcessorType__c` of "Flow".
 * Each flow expects the following parameters:
 * 	- `AsyncAction__c asyncAction` [input & output]
 *  - `AsyncActionProcessor__mdt settings` [input]
 * This enables subscribers to define simple async action logic in flow, without using apex.
 */
public class AsyncActionFlowProcessor implements AsyncActions.Processor {
	/**
	 * @description Test visible parameter name for the AsyncAction__c input/output parameter in flows
	 */
	@TestVisible
	private static String actionParameter = 'asyncAction';

	/**
	 * @description Parameter name for the AsyncActionProcessor__mdt settings input parameter in flows
	 */
	private static String settingsParameter = 'settings';

	/**
	 * @description Constructs an AsyncActionFlowProcessor and validates that the specified flow exists.
	 * @param settings The processor configuration containing the flow name to validate
	 */
	public AsyncActionFlowProcessor(AsyncActionProcessor__mdt settings) {
		AsyncActionFlowProcessor.validateFlowExists(settings);
	}

	/**
	 * @description Processes async actions by executing the configured flow for each action.
	 * @param settings The processor configuration metadata
	 * @param actions List of AsyncAction__c records to process through the flow
	 */
	public void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
		// Re-validate that the flow exists; to guard against flows deleted during an ongoing job
		AsyncActionFlowProcessor.validateFlowExists(settings);
		// Run the flow logic with the current settings & action records
		new FlowContainer(settings, actions)?.runFlow();
	}

	/**
	 * @description Validates that the specified flow exists by attempting to create an interview
	 * @param settings The processor configuration containing the flow name to validate
	 */
	private static void validateFlowExists(AsyncActionProcessor__mdt settings) {
		// Note: The Invocable.Actions class will fail silently if an invalid flow name is given
		// To prevent this, use the Flow.Interview class to check if the flow exists
		// if the flow does not exist, a System.TypeException will be thrown
		String flowName = settings?.Processor__c;
		Flow.Interview.createInterview(flowName, new Map<String, Object>{});
	}

	/**
	 * @description Validates that the invocable action result was successful
	 * @param result The invocable action result to validate
	 */
	private static void validateIsSuccess(Invocable.Action.Result result) {
		// Throw an exception if the provided invocable failed for any reason
		if (result?.isSuccess() == false) {
			String msg = result?.getErrors()?.get(0)?.getMessage();
			throw new System.FlowException(msg);
		}
	}

	/**
	 * @description Test visible method to validate that the flow result contains required output parameters
	 * @param result The invocable action result to validate
	 */
	@TestVisible
	private static void validateOutputParams(Invocable.Action.Result result) {
		// Throw an exception if the provided invocable doesn't expose an AsyncAction__c record as an output
		if (result?.getOutputParameters()?.containsKey(actionParameter) == false) {
			throw new System.FlowException('Missing required output parameter: ' + actionParameter);
		}
	}

	// **** INNER **** //
	/**
	 * @description Inner class that manages flow execution and result handling for async actions
	 */
	private class FlowContainer {
		/**
		 * @description List of async actions to process through the flow
		 */
		private List<AsyncAction__c> actions;

		/**
		 * @description The invocable action representing the flow to execute
		 */
		private Invocable.Action flow;

		/**
		 * @description The processor configuration metadata
		 */
		private AsyncActionProcessor__mdt settings;

		/**
		 * @description Constructs a FlowContainer and sets up the flow for execution
		 * @param settings The processor configuration metadata
		 * @param actions List of async actions to process
		 */
		public FlowContainer(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
			this.settings = settings;
			this.actions = actions;
			this.flow = Invocable.Action.createCustomAction('flow', settings?.Processor__c);
			this.addInvocationsToFlow();
		}

		/**
		 * @description Executes the flow and handles results for all actions
		 */
		public void runFlow() {
			// Invoke the flow, and handle its results
			List<Invocable.Action.Result> results = this.flow?.invoke();
			for (Integer i = 0; i < results?.size(); i++) {
				Invocable.Action.Result result = results?.get(i);
				AsyncAction__c action = this.actions?.get(i);
				this.handleResult(result, action);
			}
		}

		/**
		 * @description Adds invocations to the flow for each async action with appropriate parameters
		 */
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

		/**
		 * @description Test visible method to handle the result of a flow execution for a single action
		 * @param result The flow execution result
		 * @param action The async action that was processed
		 */
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

		/**
		 * @description Updates the in-memory async action record with values from the flow result
		 * @param result The flow execution result containing updated action values
		 * @param original The original async action record to update
		 */
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
