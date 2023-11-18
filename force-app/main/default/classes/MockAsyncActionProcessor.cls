@IsTest
public class MockAsyncActionProcessor extends AsyncActionProcessor {
	// This sample processor creates X number of Cases
	// for the related account represented in RelatedRecordId__c
	// The number of cases is taken from a property stored in Data__c
	public Exception error = new System.DmlException();
	public Path pathType = Path.SUCCESS;
	public AsyncActionProcessor.RetryBehavior retryBehavior = AsyncActionProcessor.RetryBehavior.ALLOW_RETRY;

	public virtual override void process(List<AsyncAction__c> actions) {
		List<Case> cases = new List<Case>();
		if (this.pathType == Path.JOB_ERROR) {
			throw this.error;
		} else if (this.pathType == Path.FAIL) {
			this.fail(actions, this.retryBehavior, 'This is a test error');
		} else {
			for (AsyncAction__c action : actions) {
				// Create cases for the action's related account
				Map<String, Object> params = this.getData(action);
				Integer numCases = (Integer) params?.get('numCases');
				for (Integer i = 0; i < numCases; i++) {
					Case myCase = new Case(AccountId = action?.RelatedRecordId__c);
					cases.add(myCase);
				}
				// Mark the action as completed - this naive implementation doesn't handle failures!
				action.Status__c = AsyncActionProcessor.Status.COMPLETED.name();
			}
		}
		insert cases;
		update actions;
	}

	public override void finalize(System.FinalizerContext context) {
		if (this.pathType == Path.FINALIZER_ERROR) {
			throw this.error;
		} else {
			super.finalize(context);
		}
	}

	public virtual override Type getType() {
		return MockAsyncActionProcessor.class;
	}

	private Map<String, Object> getData(AsyncAction__c action) {
		String data = action?.Data__c;
		return data != null ? (Map<String, Object>) JSON.deserializeUntyped(action?.Data__c) : null;
	}

	// **** INNER **** //
	public enum Path {
		FAIL,
		JOB_ERROR,
		FINALIZER_ERROR,
		SUCCESS
	}
}
