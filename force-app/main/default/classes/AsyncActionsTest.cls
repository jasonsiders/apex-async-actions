@IsTest
private class AsyncActionsTest {
	@IsTest
	static void shouldInitializeAnAction() {
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);

		Test.startTest();
		AsyncAction__c action = AsyncActions.initAction(settings);
		Test.stopTest();

		Assert.areEqual(settings?.Retries__c, action?.Retries__c, 'Wrong # of retries');
		Assert.areEqual(settings?.DeveloperName, action?.ProcessorName__c, 'Unexpected Processor Class');
		Assert.isNotNull(action?.NextEligibleAt__c, 'Invalid Next Eligible At value');
		Assert.areEqual(AsyncActions.Status.PENDING.name(), action?.Status__c, 'Unexpected Status');
	}

	@IsTest
	static void shouldInitializeAnActionFromRecordId() {
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		Id recordId = UserInfo.getUserId();
		String data = '{}';

		// Should work w/Id & data
		AsyncAction__c action1 = AsyncActions.initAction(settings, recordId, data);
		Assert.areEqual(recordId, action1?.RelatedRecordId__c, 'Wrong Related Record Id');
		Assert.areEqual(data, action1?.Data__c, 'Wrong Data');

		// Should work w/Id only
		AsyncAction__c action2 = AsyncActions.initAction(settings, recordId);
		Assert.areEqual(recordId, action2?.RelatedRecordId__c, 'Wrong Related Record Id');
		Assert.areEqual(null, action2?.Data__c, 'Wrong Data');
	}

	@IsTest
	static void shouldInitializeActionsFromSObjects() {
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		User user = new User(Id = UserInfo.getUserId());
		String data = '{}';

		// Should work w/SObjects & data
		AsyncAction__c action1 = AsyncActions.initAction(settings, user, data);
		Assert.areEqual(user?.Id, action1?.RelatedRecordId__c, 'Wrong Related Record Id');
		Assert.areEqual(data, action1?.Data__c, 'Wrong Data');

		// Should work w/SObjects only
		AsyncAction__c action2 = AsyncActions.initAction(settings, user);
		Assert.areEqual(user?.Id, action2?.RelatedRecordId__c, 'Wrong Related Record Id');
		Assert.areEqual(null, action2?.Data__c, 'Wrong Data');
	}
}
