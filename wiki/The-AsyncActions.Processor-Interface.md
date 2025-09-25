The `AsyncActions.Processor` interface defines the contract that all async action processors must implement. Both Apex classes and Flow processors (via wrapper) implement this interface.

```apex
global interface Processor {
	void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions);
}
```

## Methods

### `process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions)`
