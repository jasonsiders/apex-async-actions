@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class AsyncActionRelatedListControllerTest {
	private static final Integer NUM_TEST_ACTIONS = 200;
	private static final String TEST_USER_ALIAS = 'tUser123';

	@TestSetup
	static void setup() {
		AsyncActionRelatedListControllerTest.createTestUser();
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
		User user = AsyncActionRelatedListControllerTest.getTestUser();
		// By default, this user does not have access. Assign them a permission set
		AsyncActionRelatedListControllerTest.assignPermissionSet(user);

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
	static void assignPermissionSet(User user) {
		PermissionSet permissionSet = AsyncActionRelatedListControllerTest.getPermissionSet();
		PermissionSetAssignment assignment = new PermissionSetAssignment(
			AssigneeId = user?.Id,
			PermissionSetId = permissionSet?.Id
		);
		Database.insert(assignment, true, System.AccessLevel.USER_MODE);
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
			Database.insert(user, System.AccessLevel.SYSTEM_MODE);
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

	static PermissionSet getPermissionSet() {
		return [SELECT Id FROM PermissionSet WHERE Name = 'AsyncActionAdministrator' WITH SYSTEM_MODE LIMIT 1] ?? null;
	}
}
