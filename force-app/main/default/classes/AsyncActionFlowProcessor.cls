public class AsyncActionFlowProcessor extends AsyncActionProcessor {
	@TestVisible
	private AsyncActionProcessor__mdt config;

	public AsyncActionFlowProcessor(AsyncActionProcessor__mdt config) {
		this.config = config;
	}

	public override Type getType() {
		return AsyncActionFlowProcessor.class;
	}

	public override void process(List<AsyncAction__c> actions) {
		// ! TODO
	}
}
