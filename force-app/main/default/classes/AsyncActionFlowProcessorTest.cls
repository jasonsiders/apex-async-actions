@IsTest
private class AsyncActionFlowProcessorTest {
	private static final String TEST_FLOW_NAME = 'Template_Async_Action_Flow';
	private static final Integer TEST_SIZE = 200;

	@TestSetup
	static void setup() {
		AsyncActionProcessor__mdt settings = AsyncActionFlowProcessorTest.initSettings();
		// Insert AsyncActions, but do not run the trigger logic
		AsyncActionTriggerFramework.disable(AsyncActionTriggerHandler.class);
		List<AsyncAction__c> actions = new List<AsyncAction__c>();
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
		new AsyncActionFlowProcessor()?.process(settings, actions);
		Test.stopTest();

		// The processor should update the status records in memory
		for (AsyncAction__c action : actions) {
			Assert.areEqual(AsyncActions.Status.COMPLETED.name(), action?.Status__c, 'Wrong Status');
		}
	}

	@IsTest
	static void shouldThrowErrorIfInvalidFlowName() {
		AsyncActionProcessor__mdt settings = AsyncActionFlowProcessorTest.initSettings();
		settings.Processor__c = 'Fake_Flow_123';
		List<AsyncAction__c> actions = AsyncActionFlowProcessorTest.getActions();

		Test.startTest();
		new AsyncActionFlowProcessor()?.process(settings, actions);
		Test.stopTest();

		for (AsyncAction__c action : actions) {
			Assert.areEqual(AsyncActions.Status.FAILED.name(), action?.Status__c, 'Wrong Status');
		}
	}

	@IsTest
	static void shouldHandleMissingInputParameters() {
		AsyncActionProcessor__mdt settings = AsyncActionFlowProcessorTest.initSettings();
		List<AsyncAction__c> actions = AsyncActionFlowProcessorTest.getActions();
		// Simulate a flow with invalid input parameter names
		AsyncActionFlowProcessor.actionParameter = 'someInvalidParameterName';

		Test.startTest();
		new AsyncActionFlowProcessor()?.process(settings, actions);
		Test.stopTest();

		for (AsyncAction__c action : actions) {
			Assert.areEqual(AsyncActions.Status.FAILED.name(), action?.Status__c, 'Wrong Status');
		}
	}

	// **** HELPER **** //
	private static List<AsyncAction__c> getActions() {
		return [SELECT Id, Status__c FROM AsyncAction__c];
	}

	private static AsyncActionProcessor__mdt initSettings() {
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initFlowProcessor(TEST_FLOW_NAME);
		settings.Retries__c = 0;
		return settings;
	}
}
