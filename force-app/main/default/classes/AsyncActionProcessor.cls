@SuppressWarnings('PMD.AvoidGlobalModifier')
global interface AsyncActionProcessor {
	/**
	 * This interface defines the logic to be performed in an Async Action
	 * Create a class that implements this interface,
	 * and list the fully qualified api name of that class in AsyncActionProcessor__mdt.Processor__c
	 **/
	void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions);
}
