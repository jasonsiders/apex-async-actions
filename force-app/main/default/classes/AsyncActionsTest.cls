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

	@IsTest
	static void shouldTryAgainIfHasRetries() {
		AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		settings.Retries__c = 3;
		settings.RetryInterval__c = 3;
		AsyncAction__c action = AsyncActions.initAction(settings);
		// Note: the single-arg constructor will use "ALLOW_RETRY" behavior by default
		AsyncActions.Failure failure = new AsyncActions.Failure(settings);

		Test.startTest();
		failure?.fail(action, new System.DmlException());
		Test.stopTest();

		Assert.areEqual(AsyncActions.Status.PENDING.name(), action?.Status__c, 'Action is no longer pending');
		Assert.areEqual(settings?.Retries__c - 1, action?.Retries__c, 'Wrong Num Retries');
		DateTime now = DateTime.now();
		DateTime nextEligibleAt = action?.NextEligibleAt__c;
		Assert.isTrue(
			nextEligibleAt > now,
			'Next Eligible At is not in the future: ' + nextEligibleAt + '. Expected: ' + now
		);
	}

	@IsTest
	static void shouldNotTryAgainIfNoRetries() {
		AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		settings.Retries__c = 0;
		AsyncAction__c action = AsyncActions.initAction(settings);
		AsyncActions.Failure failure = new AsyncActions.Failure(settings, AsyncActions.RetryBehavior.ALLOW_RETRY);

		Test.startTest();
		failure?.fail(action, new System.DmlException());
		Test.stopTest();

		Assert.areEqual(AsyncActions.Status.FAILED.name(), action?.Status__c, 'Action was not marked as failed');
		Assert.isNotNull(action?.Error__c, 'Missing Error details');
	}

	@IsTest
	static void shouldKeepAliveIfErrors() {
		// If KEEP_ALIVE retry behavior is employed, an action will remain in "Pending", and its retries will not be decremented.
		AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		settings.Retries__c = 3;
		settings.RetryInterval__c = 3;
		AsyncAction__c action = AsyncActions.initAction(settings);
		AsyncActions.Failure failure = new AsyncActions.Failure(settings, AsyncActions.RetryBehavior.KEEP_ALIVE);

		Test.startTest();
		failure?.fail(action, new System.DmlException());
		Test.stopTest();

		Assert.areEqual(AsyncActions.Status.PENDING.name(), action?.Status__c, 'Action is not longer pending');
		Assert.areEqual(settings?.Retries__c, action?.Retries__c, 'Retries was altered');
		Assert.isTrue(action?.NextEligibleAt__c > DateTime.now(), 'Action was not rescheduled');
	}

	@IsTest
	static void shouldNotTryAgainIfSuddenDeath() {
		// If SUDDEN_DEATH retry behavior is employed, an action will be marked as "Failed", even if it has retries
		AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		settings.Retries__c = 3;
		AsyncAction__c action = AsyncActions.initAction(settings);
		AsyncActions.Failure failure = new AsyncActions.Failure(settings, AsyncActions.RetryBehavior.SUDDEN_DEATH);

		Test.startTest();
		failure?.fail(action, new System.DmlException());
		Test.stopTest();

		Assert.areEqual(AsyncActions.Status.FAILED.name(), action?.Status__c, 'Action was not marked as failed');
		Assert.isNotNull(action?.Error__c, 'Missing Error details');
	}
}
