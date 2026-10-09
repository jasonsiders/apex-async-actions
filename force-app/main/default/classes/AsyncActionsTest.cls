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
		Map<Id, AsyncActions.RecordGroup> groups = AsyncActions.groupByRecord(settings, actions);
		Test.stopTest();

		Assert.areEqual(new Set<Id>{ userId, profileId }, groups?.keySet(), 'Wrong record Ids');
		Assert.areEqual(userId, groups?.get(userId)?.getRecordId(), 'Wrong record Id for the group');
		Assert.areEqual(2, groups?.get(userId)?.getActions()?.size(), 'Duplicates should share a group');
		Assert.areEqual(1, groups?.get(profileId)?.getActions()?.size(), 'Wrong # of actions for the profile');
		for (AsyncAction__c action : actions) {
			Assert.areEqual(AsyncActions.Status.PENDING.name(), action?.Status__c, 'Grouping should not change status');
		}
	}

	@IsTest
	static void shouldGroupActionsWithoutARecordUnderNull() {
		// Actions with no related record are valid, so they share a group rather than fail, even as duplicates
		AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		AsyncAction__c missing = AsyncActions.initAction(settings);
		AsyncAction__c empty = AsyncActions.initAction(settings);
		empty.RelatedRecordId__c = '';
		AsyncAction__c blank = AsyncActions.initAction(settings);
		blank.RelatedRecordId__c = ' ';
		List<AsyncAction__c> actions = new List<AsyncAction__c>{ missing, empty, blank };
		AsyncActions.DuplicateBehavior behavior = AsyncActions.DuplicateBehavior.FAIL_DUPLICATES;

		Test.startTest();
		Map<Id, AsyncActions.RecordGroup> groups = AsyncActions.groupByRecord(settings, actions, behavior);
		Test.stopTest();

		Assert.areEqual(new Set<Id>{ null }, groups?.keySet(), 'Should group under the null key');
		Assert.areEqual(actions, groups?.get(null)?.getActions(), 'Wrong actions without a record');
		for (AsyncAction__c action : actions) {
			Assert.areEqual(AsyncActions.Status.PENDING.name(), action?.Status__c, 'Should not fail');
		}
	}

	@IsTest
	static void shouldFailActionsWithAnInvalidRecordId() {
		// Bad text can reach the field through DML or data loads, and must not throw for the rest of the batch
		AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		Id userId = UserInfo.getUserId();
		AsyncAction__c invalid = AsyncActions.initAction(settings);
		invalid.RelatedRecordId__c = 'not-an-id';
		AsyncAction__c valid = AsyncActions.initAction(settings, userId);
		List<AsyncAction__c> actions = new List<AsyncAction__c>{ invalid, valid };

		Test.startTest();
		Map<Id, AsyncActions.RecordGroup> groups = AsyncActions.groupByRecord(settings, actions);
		Test.stopTest();

		Assert.areEqual(new Set<Id>{ userId }, groups?.keySet(), 'Wrong record Ids');
		Assert.areEqual(AsyncActions.Status.FAILED.name(), invalid?.Status__c, 'Should fail without retries');
		Assert.isTrue(
			invalid?.Error__c?.contains('not-an-id'),
			'Error should name the bad value: ' + invalid?.Error__c
		);
		Assert.areEqual(AsyncActions.Status.PENDING.name(), valid?.Status__c, 'A valid action should not fail');
	}

	@IsTest
	static void shouldFailDuplicateActionsWhenConfigured() {
		AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		Id userId = UserInfo.getUserId();
		AsyncAction__c first = AsyncActions.initAction(settings, userId);
		AsyncAction__c duplicate = AsyncActions.initAction(settings, userId);
		List<AsyncAction__c> actions = new List<AsyncAction__c>{ first, duplicate };
		AsyncActions.DuplicateBehavior behavior = AsyncActions.DuplicateBehavior.FAIL_DUPLICATES;

		Test.startTest();
		Map<Id, AsyncActions.RecordGroup> groups = AsyncActions.groupByRecord(settings, actions, behavior);
		Test.stopTest();

		List<AsyncAction__c> kept = new List<AsyncAction__c>{ first };
		Assert.areEqual(kept, groups?.get(userId)?.getActions(), 'Should keep the first action');
		Assert.areEqual(AsyncActions.Status.PENDING.name(), first?.Status__c, 'The first action should not fail');
		Assert.areEqual(AsyncActions.Status.FAILED.name(), duplicate?.Status__c, 'Should fail without retries');
		Assert.isTrue(duplicate?.Error__c?.contains('Duplicate'), 'Wrong error: ' + duplicate?.Error__c);
	}

	@IsTest
	static void shouldCompleteEveryActionForARecord() {
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		Id userId = UserInfo.getUserId();
		Id profileId = UserInfo.getProfileId();
		AsyncAction__c first = AsyncActions.initAction(settings, userId);
		AsyncAction__c second = AsyncActions.initAction(settings, userId);
		AsyncAction__c other = AsyncActions.initAction(settings, profileId);
		List<AsyncAction__c> actions = new List<AsyncAction__c>{ first, second, other };
		AsyncActions.RecordGroup recordGroup = AsyncActions.groupByRecord(settings, actions)?.get(userId);

		Test.startTest();
		recordGroup?.complete();
		Test.stopTest();

		Assert.areEqual(AsyncActions.Status.COMPLETED.name(), first?.Status__c, 'First action not completed');
		Assert.areEqual(AsyncActions.Status.COMPLETED.name(), second?.Status__c, 'Second action not completed');
		Assert.areEqual(AsyncActions.Status.PENDING.name(), other?.Status__c, 'Another record should be untouched');
	}

	@IsTest
	static void shouldCancelEveryActionForARecord() {
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		Id userId = UserInfo.getUserId();
		AsyncAction__c first = AsyncActions.initAction(settings, userId);
		AsyncAction__c second = AsyncActions.initAction(settings, userId);
		List<AsyncAction__c> actions = new List<AsyncAction__c>{ first, second };
		AsyncActions.RecordGroup recordGroup = AsyncActions.groupByRecord(settings, actions)?.get(userId);

		Test.startTest();
		recordGroup?.cancel();
		Test.stopTest();

		Assert.areEqual(AsyncActions.Status.CANCELED.name(), first?.Status__c, 'First action not canceled');
		Assert.areEqual(AsyncActions.Status.CANCELED.name(), second?.Status__c, 'Second action not canceled');
	}

	@IsTest
	static void shouldFailEveryActionForARecordWithRetries() {
		AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		Id userId = UserInfo.getUserId();
		AsyncAction__c first = AsyncActions.initAction(settings, userId);
		AsyncAction__c second = AsyncActions.initAction(settings, userId);
		List<AsyncAction__c> actions = new List<AsyncAction__c>{ first, second };
		AsyncActions.RecordGroup recordGroup = AsyncActions.groupByRecord(settings, actions)?.get(userId);
		Exception error = new System.DmlException();

		Test.startTest();
		recordGroup?.fail(error);
		Test.stopTest();

		for (AsyncAction__c action : actions) {
			Assert.areEqual(AsyncActions.Status.PENDING.name(), action?.Status__c, 'Should stay pending to retry');
			Assert.areEqual(settings?.Retries__c - 1, action?.Retries__c, 'Should spend a retry');
			Assert.isNotNull(action?.Error__c, 'Missing Error details');
		}
	}

	@IsTest
	static void shouldNotLetCallersEmptyAGroup() {
		// A caller's remove() on the group's own list would leave that action Pending
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(MockAsyncActionProcessor.class);
		Id userId = UserInfo.getUserId();
		AsyncAction__c action = AsyncActions.initAction(settings, userId);
		List<AsyncAction__c> actions = new List<AsyncAction__c>{ action };
		AsyncActions.RecordGroup recordGroup = AsyncActions.groupByRecord(settings, actions)?.get(userId);

		Test.startTest();
		recordGroup?.getActions()?.clear();
		recordGroup?.complete();
		Test.stopTest();

		Assert.areEqual(AsyncActions.Status.COMPLETED.name(), action?.Status__c, 'Callers should not empty a group');
	}
}
