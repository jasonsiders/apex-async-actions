@IsTest
private class AsyncActionErrorHandlerTest {
	@IsTest
	static void shouldTryAgainIfHasRetries() {
		AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		settings.Retries__c = 3;
		settings.RetryInterval__c = 3;
		AsyncAction__c action = AsyncActions.initAction(settings);
		// Note: the single-arg constructor will use "ALLOW_RETRY" behavior by default
		AsyncActionErrorHandler handler = new AsyncActionErrorHandler(settings);

		Test.startTest();
		handler?.handleError(action, new System.DmlException());
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
		AsyncActionErrorHandler handler = new AsyncActionErrorHandler(
			settings,
			AsyncActionErrorHandler.RetryBehavior.ALLOW_RETRY
		);

		Test.startTest();
		handler?.handleError(action, new System.DmlException());
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
		AsyncActionErrorHandler handler = new AsyncActionErrorHandler(
			settings,
			AsyncActionErrorHandler.RetryBehavior.KEEP_ALIVE
		);

		Test.startTest();
		handler?.handleError(action, new System.DmlException());
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
		AsyncActionErrorHandler handler = new AsyncActionErrorHandler(
			settings,
			AsyncActionErrorHandler.RetryBehavior.SUDDEN_DEATH
		);

		Test.startTest();
		handler?.handleError(action, new System.DmlException());
		Test.stopTest();

		Assert.areEqual(AsyncActions.Status.FAILED.name(), action?.Status__c, 'Action was not marked as failed');
		Assert.isNotNull(action?.Error__c, 'Missing Error details');
	}
}
