@IsTest
public class MockAsyncActionJob extends AsyncActionJob {
	// This sample processor creates X number of Cases
	// for the related account represented in RelatedRecordId__c
	// The number of cases is taken from a property stored in Data__c
	public static Exception error = new System.DmlException();
	public static Path pathType = Path.SUCCESS;
	public static AsyncActionJob.RetryBehavior retryBehavior = AsyncActionJob.RetryBehavior.ALLOW_RETRY;

	public MockAsyncActionJob(AsyncActionProcessor__mdt settings) {
		super(settings);
	}

	public override void finalize(System.FinalizerContext context) {
		if (MockAsyncActionJob.pathType == Path.FINALIZER_ERROR) {
			throw MockAsyncActionJob.error;
		} else {
			super.finalize(context);
		}
	}

	// **** INNER **** //
	public class Logic implements AsyncActionProcessor {
		public void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
			if (MockAsyncActionJob.pathType == Path.JOB_ERROR) {
				throw MockAsyncActionJob.error;
			} else if (MockAsyncActionJob.pathType == Path.FAIL) {
				new AsyncActionJob.ErrorHandler(settings, MockAsyncActionJob.retryBehavior)
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
				action.Status__c = AsyncActionJob.Status.COMPLETED.name();
			}
			insert cases;
		}

		private Map<String, Object> getData(AsyncAction__c action) {
			String data = action?.Data__c;
			return data != null ? (Map<String, Object>) JSON.deserializeUntyped(action?.Data__c) : null;
		}
	}

	public enum Path {
		FAIL,
		JOB_ERROR,
		FINALIZER_ERROR,
		SUCCESS
	}
}
