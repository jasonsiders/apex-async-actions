@IsTest
private class InvocableFailAsyncActionTest {
	@IsTest
	static void shouldHandleFailedActions() {
		Type processorType = MockAsyncActionProcessor.class;
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(processorType);
		AsyncAction__c action = AsyncActions.initAction(settings);
		InvocableFailAsyncAction.Input input = InvocableFailAsyncActionTest.initInput(settings, action);
		List<InvocableFailAsyncAction.Input> inputs = new List<InvocableFailAsyncAction.Input>{ input };

		Test.startTest();
		InvocableFailAsyncAction.invoke(inputs);
		Test.stopTest();

		Assert.areEqual(AsyncActions.Status.FAILED.name(), action?.Status__c, 'Wrong Status');
	}

	@IsTest
	static void shouldHandleInvalidRetryBehavior() {
		Type processorType = MockAsyncActionProcessor.class;
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(processorType);
		settings.Retries__c = 3;
		AsyncAction__c action = AsyncActions.initAction(settings);
		InvocableFailAsyncAction.Input input = InvocableFailAsyncActionTest.initInput(settings, action);
		input.retryBehaviorName = 'foo_bar_123'; // ! Should default to ALLOW_RETRY if invalid
		List<InvocableFailAsyncAction.Input> inputs = new List<InvocableFailAsyncAction.Input>{ input };

		Test.startTest();
		InvocableFailAsyncAction.invoke(inputs);
		Test.stopTest();

		Assert.areEqual(AsyncActions.Status.PENDING.name(), action?.Status__c, 'Wrong Status');
		Assert.areEqual(settings?.Retries__c - 1, action?.Retries__c, 'Retries was not decremented');
	}

	@IsTest
	static void shouldHandleInvalidDeveloperName() {
		Type processorType = MockAsyncActionProcessor.class;
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(processorType);
		AsyncAction__c action = AsyncActions.initAction(settings);
		InvocableFailAsyncAction.Input input = InvocableFailAsyncActionTest.initInput(settings, action);
		input.developerName = 'some_invalid_developer_name';
		List<InvocableFailAsyncAction.Input> inputs = new List<InvocableFailAsyncAction.Input>{ input };

		Test.startTest();
		try {
			InvocableFailAsyncAction.invoke(inputs);
			Assert.fail('An exception was not thrown');
		} catch (System.IllegalArgumentException error) {
			// As expected...
		}
		Test.stopTest();
	}

	// **** HELPER **** //
	static InvocableFailAsyncAction.Input initInput(AsyncActionProcessor__mdt settings, AsyncAction__c action) {
		InvocableFailAsyncAction.Input input = new InvocableFailAsyncAction.Input();
		input.action = action;
		input.developerName = settings?.DeveloperName;
		input.errorMessage = 'This is a test error';
		input.retryBehaviorName = AsyncActions.RetryBehavior.SUDDEN_DEATH.name();
		return input;
	}
}
