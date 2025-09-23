@IsTest
public class MockAsyncActionProcessor implements AsyncActions.Processor {
	/**
	 * This sample processor provides a mechanism to test various paths in the AsyncActionJob
	 * By itself, it does nothing -- it simply marks the provided actions as completed
	 * Test consumers can modify any of its public static properties to determine its behavior
	 **/
	public static Exception error = new System.DmlException();
	public static MockAsyncActionProcessor.Path pathType = MockAsyncActionProcessor.Path.SUCCESS;
	public static AsyncActions.RetryBehavior retryBehavior = AsyncActions.RetryBehavior.ALLOW_RETRY;

	public void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
		if (pathType == MockAsyncActionProcessor.Path.THROW_ERROR) {
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
		SUCCESS,
		THROW_ERROR
	}
}
