@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class RunAsyncActionNowControllerTest {
	@TestSetup
	static void setup() {
		Account account = new Account(Name = 'Test Account');
		Database.insert(account, System.AccessLevel.SYSTEM_MODE);
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		settings.Retries__c = 0;
		settings.RunOnInsert__c = false;
		String data = JSON.serialize(new Map<String, Object>{ 'numCases' => 1 });
		AsyncAction__c action = AsyncActions.initAction(settings, account?.Id, data);
		action.Status__c = AsyncActions.Status.CANCELED.name();
		Database.insert(action, System.AccessLevel.SYSTEM_MODE);
	}

	// **** TESTS **** //
	@IsTest
	static void shouldLaunchAction() {
		AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		AsyncAction__c action = RunAsyncActionNowControllerTest.getAction();

		Test.startTest();
		RunAsyncActionNowController.runAction(action?.Id);
		Test.getEventBus().deliver();
		Test.stopTest();

		action = RunAsyncActionNowControllerTest.getAction();
		Assert.areEqual(AsyncActions.Status.COMPLETED.name(), action?.Status__c, 'Action was not processed');
	}

	@IsTest
	static void shouldHandleFutureScheduledAction() {
		AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		AsyncAction__c action = RunAsyncActionNowControllerTest.getAction();
		// The action should process this action now, regardless of its Next Eligible At value
		action.NextEligibleAt__c = DateTime.now().addDays(10);
		Database.update(action, System.AccessLevel.SYSTEM_MODE);

		Test.startTest();
		RunAsyncActionNowController.runAction(action?.Id);
		Test.getEventBus().deliver();
		Test.stopTest();

		action = RunAsyncActionNowControllerTest.getAction();
		Assert.areEqual(AsyncActions.Status.COMPLETED.name(), action?.Status__c, 'Action was not processed');
	}

	@IsTest
	static void shouldHandleErrors() {
		AuraHandledException auraError;

		Test.startTest();
		try {
			RunAsyncActionNowController.runAction('not a real id');
		} catch (AuraHandledException caughtError) {
			auraError = caughtError;
		}
		Test.stopTest();

		Assert.isNotNull(auraError, 'AuraHandledException');
	}

	// **** HELPER **** //
	static AsyncAction__c getAction() {
		List<AsyncAction__c> actions = [
			SELECT Id, NextEligibleAt__c, Status__c
			FROM AsyncAction__c
			ORDER BY CreatedDate DESC
			LIMIT 1
		];
		return actions?.isEmpty() == false ? actions[0] : null;
	}
}
