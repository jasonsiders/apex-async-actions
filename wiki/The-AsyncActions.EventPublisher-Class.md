The `AsyncActions.EventPublisher` inner class starts processors and enforces scheduled jobs by publishing the package's platform events. Use it instead of publishing `AsyncActionStart__e` or `AsyncActionSchedule__e` yourself.

It publishes in system mode, so the running user needs no Create access on either event. Since API version 67.0, `EventBus.publish()` fails for users without that access, and returns a failed `SaveResult` instead of throwing. Failed publishes are logged at `ERROR` through the [AsyncActionLogger](./The-AsyncActionLogger.Adapter-Interface).

Both events publish after the transaction commits, so nothing starts if it rolls back.

```apex
AsyncActions.EventPublisher publisher = new AsyncActions.EventPublisher();
publisher.start('My_Processor');
```

## Methods

### `start`

Starts the named processors. Each name is the `DeveloperName` of an [AsyncActionProcessor\_\_mdt](./The-AsyncActionProcessor__mdt-Custom-Metadata-Type) record. Blank or empty input starts nothing.

- `void start(Iterable<String> processorNames)`
- `void start(String processorName)`

### `startAll`

Starts every processor.

- `void startAll()`

### `enforceScheduledJobs`

Checks that each enabled [AsyncActionScheduledJob\_\_mdt](./The-AsyncActionScheduledJob__mdt-Custom-Metadata-Type) has a matching scheduled job, and that no disabled or deleted one does. Publishes `AsyncActionSchedule__e` only if something needs to change. Its trigger then aborts and reschedules jobs as the Automated Process user, which owns the new jobs.

- `void enforceScheduledJobs()`

The framework calls this after `AsyncAction__c` records are inserted and after each scheduled run, so you rarely need to call it yourself. Call it after aborting jobs by hand, to reschedule them right away.

Since v4.2.0, scheduled jobs change only after the transaction commits. A test that inserts `AsyncAction__c` records and then checks for a scheduled job must call `Test.getEventBus().deliver()` first.
