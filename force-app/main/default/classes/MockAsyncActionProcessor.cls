@SuppressWarnings('PMD.ApexDoc')
@IsTest
public class MockAsyncActionProcessor implements AsyncActions.Processor {
	// This sample processor creates X number of Cases
	// for the related account represented in RelatedRecordId__c
	// The number of cases is taken from a property stored in Data__c
	public static Exception error = new System.DmlException();
	public static MockAsyncActionProcessor.Path pathType = MockAsyncActionProcessor.Path.SUCCESS;
	public static AsyncActions.RetryBehavior retryBehavior = AsyncActions.RetryBehavior.ALLOW_RETRY;

	public void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
		if (MockAsyncActionProcessor.pathType == MockAsyncActionProcessor.Path.JOB_ERROR) {
			throw MockAsyncActionProcessor.error;
		} else if (MockAsyncActionProcessor.pathType == MockAsyncActionProcessor.Path.FAIL) {
			new AsyncActions.Failure(settings, MockAsyncActionProcessor.retryBehavior)
				?.fail(actions, 'This is a test error');
		} else {
			this.createCases(actions);
		}
	}

	private void createCases(List<AsyncAction__c> actions) {
		List<Case> cases = new List<Case>();
		for (AsyncAction__c action : actions) {
			// Create cases for the action's related account
			Map<String, Object> params = this.getData(action);
			Integer numCases = (Integer) params?.get('numCases');
			for (Integer i = 0; i < numCases; i++) {
				Case myCase = new Case(AccountId = action?.RelatedRecordId__c);
				cases.add(myCase);
			}
			// Mark the action as completed - this naive implementation doesn't handle failures!
			action.Status__c = AsyncActions.Status.COMPLETED.name();
		}
		Database.insert(cases, System.AccessLevel.SYSTEM_MODE);
	}

	private Map<String, Object> getData(AsyncAction__c action) {
		String data = action?.Data__c;
		return data != null ? (Map<String, Object>) JSON.deserializeUntyped(action?.Data__c) : null;
	}

	public enum Path {
		FAIL,
		JOB_ERROR,
		SUCCESS
	}
}
