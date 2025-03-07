@IsTest
private class AsyncActionRelatedListControllerTest {
	private static final Integer NUM_TEST_ACTIONS = 200;
	private static final String TEST_USER_ALIAS = 'tUser123';

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
		User user = AsyncActionRelatedListControllerTest.getTestUser();
		// By default, this user does not have access. Assign them a permission set
		AsyncActionPermissionUtils.assignPermissionSet(user);

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
		User user = AsyncActionRelatedListControllerTest.getTestUser();
		// By default, this user does not have access

		Test.startTest();
		Boolean results;
		System.runAs(user) {
			results = AsyncActionRelatedListController.hasAccess();
		}
		Test.stopTest();

		Assert.areEqual(false, results, 'Unexpected results');
	}

	// **** HELPER **** //
	@TestSetup
	static void setup() {
		AsyncActionRelatedListControllerTest.createTestUser();
		// Create an Account
		Account account = new Account(Name = 'Test Account');
		insert account;
		// Create actions related to the Account
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(
			AsyncActionRelatedListControllerTest.class
		);
		List<AsyncAction__c> actions = new List<AsyncAction__c>();
		for (Integer i = 0; i < NUM_TEST_ACTIONS; i++) {
			AsyncAction__c action = AsyncActions.initAction(settings, account?.Id);
			actions?.add(action);
		}
		insert actions;
	}

	static User createTestUser() {
		Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
		String username = 'testuser' + Crypto.getRandomInteger() + '@test.com';
		User user = new User(
			Alias = TEST_USER_ALIAS,
			EmailEncodingKey = 'UTF-8',
			Email = username,
			FirstName = 'Test',
			LanguageLocaleKey = 'en_US',
			LastName = 'User',
			LocaleSidKey = 'en_US',
			TimeZoneSidKey = 'GMT',
			ProfileId = standardProfile?.Id,
			Username = username
		);
		// Can't mix DML ops - this is a workaround
		User me = new User(Id = UserInfo.getUserId());
		System.runAs(me) {
			insert user;
		}
		return user;
	}

	static User getTestUser() {
		return [SELECT Id FROM User WHERE Alias = :TEST_USER_ALIAS ORDER BY CreatedDate DESC LIMIT 1];
	}

	static Account getAccount() {
		List<Account> accounts = [SELECT Id FROM Account ORDER BY CreatedDate DESC LIMIT 1];
		return accounts?.isEmpty() ? null : accounts[0];
	}
}
