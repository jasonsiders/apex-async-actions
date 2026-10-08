@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
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

	@IsTest
	static void shouldGroupActionsByRelatedRecord() {
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		Id userId = UserInfo.getUserId();
		Id profileId = UserInfo.getProfileId();
		List<AsyncAction__c> actions = new List<AsyncAction__c>{
			AsyncActions.initAction(settings, userId),
			AsyncActions.initAction(settings, userId),
			AsyncActions.initAction(settings, profileId)
		};

		Test.startTest();
		AsyncActions.ActionGroups groups = new AsyncActions.ActionGroups(settings, actions);
		Test.stopTest();

		Assert.areEqual(new Set<Id>{ userId, profileId }, groups?.getRecordIds(), 'Wrong record Ids');
		Assert.areEqual(2, groups?.getActions(userId)?.size(), 'Duplicates should share a group');
		Assert.areEqual(1, groups?.getActions(profileId)?.size(), 'Wrong # of actions for the profile');
		for (AsyncAction__c action : actions) {
			Assert.areEqual(AsyncActions.Status.PENDING.name(), action?.Status__c, 'Grouping should not change status');
		}
	}

	@IsTest
	static void shouldFailActionsWithoutAValidRecordId() {
		// Bad text can reach the field through DML or data loads, and must not throw for the rest of the batch
		AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		AsyncAction__c blank = AsyncActions.initAction(settings);
		AsyncAction__c invalid = AsyncActions.initAction(settings);
		invalid.RelatedRecordId__c = 'not-an-id';
		AsyncAction__c valid = AsyncActions.initAction(settings, UserInfo.getUserId());

		Test.startTest();
		AsyncActions.ActionGroups groups = new AsyncActions.ActionGroups(
			settings,
			new List<AsyncAction__c>{ blank, invalid, valid }
		);
		Test.stopTest();

		Assert.areEqual(new Set<Id>{ UserInfo.getUserId() }, groups?.getRecordIds(), 'Wrong record Ids');
		for (AsyncAction__c action : new List<AsyncAction__c>{ blank, invalid }) {
			Assert.areEqual(AsyncActions.Status.FAILED.name(), action?.Status__c, 'Should fail without retries');
			Assert.isTrue(action?.Error__c?.contains('valid record Id'), 'Wrong error: ' + action?.Error__c);
		}
		Assert.areEqual(AsyncActions.Status.PENDING.name(), valid?.Status__c, 'A valid action should not fail');
	}

	@IsTest
	static void shouldFailDuplicateActionsWhenConfigured() {
		AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		AsyncAction__c first = AsyncActions.initAction(settings, UserInfo.getUserId());
		AsyncAction__c duplicate = AsyncActions.initAction(settings, UserInfo.getUserId());
		AsyncActions.DuplicateBehavior behavior = AsyncActions.DuplicateBehavior.FAIL_DUPLICATES;

		Test.startTest();
		AsyncActions.ActionGroups groups = new AsyncActions.ActionGroups(
			settings,
			new List<AsyncAction__c>{ first, duplicate },
			behavior
		);
		Test.stopTest();

		Assert.areEqual(
			new List<AsyncAction__c>{ first },
			groups?.getActions(UserInfo.getUserId()),
			'Should keep the first action'
		);
		Assert.areEqual(AsyncActions.Status.PENDING.name(), first?.Status__c, 'The first action should not fail');
		Assert.areEqual(AsyncActions.Status.FAILED.name(), duplicate?.Status__c, 'Should fail without retries');
		Assert.isTrue(duplicate?.Error__c?.contains('Duplicate'), 'Wrong error: ' + duplicate?.Error__c);
	}

	@IsTest
	static void shouldCompleteEveryActionForARecord() {
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		AsyncAction__c first = AsyncActions.initAction(settings, UserInfo.getUserId());
		AsyncAction__c second = AsyncActions.initAction(settings, UserInfo.getUserId());
		AsyncAction__c other = AsyncActions.initAction(settings, UserInfo.getProfileId());
		AsyncActions.ActionGroups groups = new AsyncActions.ActionGroups(
			settings,
			new List<AsyncAction__c>{ first, second, other }
		);

		Test.startTest();
		groups?.complete(UserInfo.getUserId());
		Test.stopTest();

		Assert.areEqual(AsyncActions.Status.COMPLETED.name(), first?.Status__c, 'First action not completed');
		Assert.areEqual(AsyncActions.Status.COMPLETED.name(), second?.Status__c, 'Second action not completed');
		Assert.areEqual(AsyncActions.Status.PENDING.name(), other?.Status__c, 'Another record should be untouched');
	}

	@IsTest
	static void shouldCancelEveryActionForARecord() {
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		AsyncAction__c first = AsyncActions.initAction(settings, UserInfo.getUserId());
		AsyncAction__c second = AsyncActions.initAction(settings, UserInfo.getUserId());
		AsyncActions.ActionGroups groups = new AsyncActions.ActionGroups(
			settings,
			new List<AsyncAction__c>{ first, second }
		);

		Test.startTest();
		groups?.cancel(UserInfo.getUserId());
		Test.stopTest();

		Assert.areEqual(AsyncActions.Status.CANCELED.name(), first?.Status__c, 'First action not canceled');
		Assert.areEqual(AsyncActions.Status.CANCELED.name(), second?.Status__c, 'Second action not canceled');
	}

	@IsTest
	static void shouldFailEveryActionForARecordWithRetries() {
		AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		AsyncAction__c first = AsyncActions.initAction(settings, UserInfo.getUserId());
		AsyncAction__c second = AsyncActions.initAction(settings, UserInfo.getUserId());
		AsyncActions.ActionGroups groups = new AsyncActions.ActionGroups(
			settings,
			new List<AsyncAction__c>{ first, second }
		);

		Test.startTest();
		groups?.fail(UserInfo.getUserId(), new System.DmlException());
		Test.stopTest();

		for (AsyncAction__c action : new List<AsyncAction__c>{ first, second }) {
			Assert.areEqual(AsyncActions.Status.PENDING.name(), action?.Status__c, 'Should stay pending to retry');
			Assert.areEqual(settings?.Retries__c - 1, action?.Retries__c, 'Should spend a retry');
			Assert.isNotNull(action?.Error__c, 'Missing Error details');
		}
	}

	@IsTest
	static void shouldIgnoreRecordsOutsideTheBatch() {
		AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		AsyncAction__c action = AsyncActions.initAction(settings, UserInfo.getUserId());
		AsyncActions.ActionGroups groups = new AsyncActions.ActionGroups(settings, new List<AsyncAction__c>{ action });
		Id outsideId = UserInfo.getProfileId();

		Test.startTest();
		groups?.complete(outsideId);
		groups?.cancel(outsideId);
		groups?.fail(outsideId, 'Should not apply');
		Test.stopTest();

		Assert.isTrue(groups?.getActions(outsideId)?.isEmpty(), 'Should have no actions for the record');
		Assert.areEqual(AsyncActions.Status.PENDING.name(), action?.Status__c, 'Should not touch other actions');
		Assert.isNull(action?.Error__c, 'Should not fail other actions');
	}
}
