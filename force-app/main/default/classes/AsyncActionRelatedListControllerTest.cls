@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class AsyncActionRelatedListControllerTest {
	private static final Integer NUM_TEST_ACTIONS = 200;

	@TestSetup
	static void setup() {
		// Create an Account
		Account account = new Account(Name = 'Test Account');
		Database.insert(account, System.AccessLevel.SYSTEM_MODE);
		// Create actions related to the Account
		Type thisClass = AsyncActionRelatedListControllerTest.class;
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(thisClass);
		List<AsyncAction__c> actions = new List<AsyncAction__c>{};
		for (Integer i = 0; i < NUM_TEST_ACTIONS; i++) {
			AsyncAction__c action = AsyncActions.initAction(settings, account?.Id);
			actions?.add(action);
		}
		Database.insert(actions, System.AccessLevel.SYSTEM_MODE);
	}

	// **** TESTS **** //
	@IsTest
	static void shouldReturnRelatedActions() {
		Account account = AsyncActionRelatedListControllerTest.getAccount();

		Test.startTest();
		List<AsyncAction__c> actions = AsyncActionRelatedListController.getActions(account?.Id);
		Test.stopTest();

		Assert.areEqual(NUM_TEST_ACTIONS, actions?.size(), 'Wrong # of actions');
		for (AsyncAction__c action : actions) {
			Assert.areEqual(account?.Id, action?.RelatedRecordId__c, 'Wrong Related Record Id');
		}
	}

	@IsTest
	static void shouldHandleNullId() {
		Id recordId = null;

		Test.startTest();
		Exception error;
		try {
			AsyncActionRelatedListController.getActions(recordId);
		} catch (AuraHandledException caughtError) {
			error = caughtError;
		}
		Test.stopTest();

		Assert.areNotEqual(null, error, 'An error was not thrown');
	}

	@IsTest
	static void shouldReturnTrueIfHasAccess() {
		User user = AsyncActionTestUtils.insertAdministrator();

		Test.startTest();
		Boolean results;
		System.runAs(user) {
			results = AsyncActionRelatedListController.hasAccess();
		}
		Test.stopTest();

		Assert.areEqual(true, results, 'Unexpected results');
	}

	@IsTest
	static void shouldReturnFalseIfNoAccess() {
		User user = AsyncActionTestUtils.insertStandardUser();

		Test.startTest();
		Boolean results;
		System.runAs(user) {
			results = AsyncActionRelatedListController.hasAccess();
		}
		Test.stopTest();

		Assert.areEqual(false, results, 'Unexpected results');
	}

	// **** HELPER **** //
	static Account getAccount() {
		List<Account> accounts = [SELECT Id FROM Account ORDER BY CreatedDate DESC LIMIT 1];
		return accounts?.isEmpty() ? null : accounts[0];
	}
}
