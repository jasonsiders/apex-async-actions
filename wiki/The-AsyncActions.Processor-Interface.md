The `AsyncActions.Processor` interface defines the contract that all async action processors must implement. Both Apex classes and Flow processors (via wrapper) implement this interface.

```apex
global interface Processor {
	void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions);
}
```

## Methods

### `process`

The core method that contains your business logic for processing async actions.

-   `void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions)`

This method receives a batch of pending actions and the processor configuration. Your implementation should process all actions in the batch, update their status appropriately, and handle any errors using the framework's failure handling mechanisms.
