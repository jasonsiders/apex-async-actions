@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.EmptyCatchBlock')
@IsTest
private class AsyncActionFlowProcessorTest {
	private static final String TEST_FLOW_NAME = 'Template_Async_Action_Flow';
	private static final Integer TEST_SIZE = 3;

	@TestSetup
	static void setup() {
		AsyncActionProcessor__mdt settings = AsyncActionFlowProcessorTest.initSettings();
		// Insert AsyncActions, but do not run the trigger logic
		AsyncActionTriggerFramework.disable(AsyncActionTriggerHandler.class);
		List<AsyncAction__c> actions = new List<AsyncAction__c>{};
		for (Integer i = 0; i < TEST_SIZE; i++) {
			AsyncAction__c action = AsyncActions.initAction(settings);
			actions?.add(action);
		}
		Database.insert(actions, System.AccessLevel.SYSTEM_MODE);
	}

	// **** TESTS **** //
	@IsTest
	static void shouldIntegrateWithAsyncActionJob() {
		AsyncActionProcessor__mdt settings = AsyncActionFlowProcessorTest.initSettings();

		Test.startTest();
		new AsyncActionLauncher()?.launch(settings);
		Test.stopTest();

		// Note: The template flow simply marks async action records as "Completed"
		List<AsyncAction__c> actions = AsyncActionFlowProcessorTest.getActions();
		Assert.areEqual(TEST_SIZE, actions?.size(), 'Wrong # of actions');
		for (AsyncAction__c action : actions) {
			Assert.areEqual(AsyncActions.Status.COMPLETED.name(), action?.Status__c, 'Wrong Status');
		}
	}

	@IsTest
	static void shouldRunFlowLogic() {
		AsyncActionProcessor__mdt settings = AsyncActionFlowProcessorTest.initSettings();
		List<AsyncAction__c> actions = AsyncActionFlowProcessorTest.getActions();

		Test.startTest();
		new AsyncActionFlowProcessor(settings)?.process(settings, actions);
		Test.stopTest();

		// Note: The template flow simply marks async action records as "Completed"
		// The processor should update the status records in memory
		for (AsyncAction__c action : actions) {
			Assert.areEqual(AsyncActions.Status.COMPLETED.name(), action?.Status__c, 'Wrong Status');
		}
	}

	@IsTest
	static void shouldHandleFlowFailures() {
		AsyncActionProcessor__mdt settings = AsyncActionFlowProcessorTest.initSettings();
		List<AsyncAction__c> actions = AsyncActionFlowProcessorTest.getActions();
		// If the flow has an unexpceted parameter name, the flow will fail:
		AsyncActionFlowProcessor.actionParameter = 'someInvalidParameterName';

		Test.startTest();
		new AsyncActionFlowProcessor(settings)?.process(settings, actions);
		Test.stopTest();

		for (AsyncAction__c action : actions) {
			Assert.areEqual(AsyncActions.Status.FAILED.name(), action?.Status__c, 'Wrong Status');
		}
	}

	@IsTest
	static void shouldThrowErrorIfInvalidFlowName() {
		AsyncActionProcessor__mdt settings = AsyncActionFlowProcessorTest.initSettings();
		settings.Processor__c = 'Fake_Flow_123';

		Test.startTest();
		try {
			new AsyncActionFlowProcessor(settings);
			Assert.fail('Did not throw an error');
		} catch (System.TypeException error) {
			// As expected...
		}
		Test.stopTest();
	}

	@IsTest
	static void shouldHandleInvalidOutputParameterNames() {
		// Instantiate a mock/empty result object, since we don't have a way to make our packaged flow fail otherwise
		// This result object does not contain any output parameters
		Invocable.Action.Result mockResult = AsyncActionFlowProcessorTest.mockFlowResult();

		Test.startTest();
		try {
			// Because the mock result doesn't contain any output parameters, the method should throw an exception
			AsyncActionFlowProcessor.validateOutputParams(mockResult);
			Assert.fail('Did not throw an exception');
		} catch (System.FlowException error) {
			// As expected...
		}
		Test.stopTest();
	}

	// **** HELPER **** //
	private static List<AsyncAction__c> getActions() {
		return [SELECT Id, Error__c, NextEligibleAt__c, Retries__c, Status__c FROM AsyncAction__c LIMIT :TEST_SIZE];
	}

	private static AsyncActionProcessor__mdt initSettings() {
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initFlowProcessor(TEST_FLOW_NAME);
		settings.Retries__c = 0;
		return settings;
	}

	private static Invocable.Action.Result mockFlowResult() {
		// Generate a mock Invocable.Action.Result, for testing error handling paths
		Map<String, Object> params = new Map<String, Object>{
			'outputParameters' => new Map<String, Object>{},
			'success' => true
		};
		return (Invocable.Action.Result) JSON.deserialize(JSON.serialize(params), Invocable.Action.Result.class);
	}
}
