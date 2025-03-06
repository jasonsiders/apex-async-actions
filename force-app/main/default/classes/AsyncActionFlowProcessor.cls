public class AsyncActionFlowProcessor extends AsyncActionProcessor {
	@TestVisible
	private AsyncActionProcessor__mdt settings;

	public AsyncActionFlowProcessor(AsyncActionProcessor__mdt settings) {
		this.settings = settings;
	}

	public override Type getType() {
		return AsyncActionFlowProcessor.class;
	}

	public override void process(List<AsyncAction__c> actions) {
		// ! TODO
	}
}
