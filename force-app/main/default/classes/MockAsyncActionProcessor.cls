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
		if (pathType == MockAsyncActionProcessor.Path.JOB_ERROR) {
			throw error;
		} else if (pathType == MockAsyncActionProcessor.Path.FAIL) {
			AsyncActions.Failure failure = new AsyncActions.Failure(settings, retryBehavior);
			failure?.fail(actions, 'This is a test error');
		} else {
			this.markAsCompleted(actions);
		}
	}

	private void markAsCompleted(List<AsyncAction__c> actions) {
		for (AsyncAction__c action : actions) {
			// Mark the action as completed
			// This naive implementation doesn't actually do anything
			action.Status__c = AsyncActions.Status.COMPLETED.name();
		}
	}

	public enum Path {
		FAIL,
		JOB_ERROR,
		SUCCESS
	}
}
