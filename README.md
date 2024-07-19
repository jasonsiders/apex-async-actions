# `apex-async-actions`

Async Actions uses the power of the Salesforce platform to make it easier to launch, process, and track business-critical asynchronous tasks. Developers can define your own custom _Actions_ through Apex code, and then control and monitor its execution with declarative tools.

## **Getting Started**

`apex-async-actions` is available as an Unlocked package. Follow these instructions to get started.

### Install/Deploy the Package

To use Async Actions in your own project, install the latest version of the package. You can find this version [here](https://github.com/jasonsiders/apex-async-actions/releases/latest).

Run this command to install the package, using the package's `04t...` Id in place of `PACKAGE_VERSION_ID`:

```
sfdx package install -p PACKAGE_VERSION_ID
```

Alternatively, if you wish to contribute to this project, you can deploy its contents directly to your org. To do this, clone the repo and then run `sfdx force source push`.

### Assign Permissions

You should assign the `AsyncActionAdministrator` permission set to yourself, along with any user that needs access to view and edit `AsyncAction__c` records. See Salesforce's [documentation](https://help.salesforce.com/s/articleView?id=sf.perm_sets_mass_assign.htm&type=5) for details.

## **Usage**

Developers can create a new _Action_ in three easy steps:

#### #1. Create an Apex Class that extends the `AsyncActionProcessor` class. This defines what the Action will do when it runs.

    ```java
    global class FooCreator extends AsyncActionProcessor {
        global override void process(List<AsyncAction__c> actions) {
            List<Foo__c> myFoos = new List<Foo__c>();
            for (AsyncAction__c action : actions) {
                Id barId = (Id) action?.RelatedRecordId__c;
                Foo__c foo = new Foo__c(Bar__c = barId);
                myFoos?.add(foo);
                action.Status__c = 'Completed';
            }
            insert myFoos;
            update actions;
        }

        global override Type getType() {
            return FooCreator.class;
        }
    }
    ```

    Read more about this class [here](/docs/ASYNCACTIONPROCESSOR.md).

#### #2. Create a `AsyncActionProcessor__mdt` custom metadata record related to the class. This can be used to configure certain aspects of the Action; for example, its _Batch Size_. Read more about this custom metadata type [here](/docs/PROCESSORSETTINGS.md).
   ![An AsyncActionProcessor__mdt Record](/media/sample_processor_config.png)

#### #3. Define how you want your action to be launched.

-   Run your action near-immediately, set `AsyncActionProcessor__mdt.RunOnInsert__c` to _true_. An instance of the job will launch shortly after corresponding `AsyncAction__c` record(s) are inserted.
-   Add your action at a regular scheduled interval, using the [`AsyncActionScheduledJob__mdt`](/docs/SCHEDULEDJOBSETTINGS.md) and [`AsyncActionScheduledJobItem__mdt`](/docs/SCHEDULEDJOBITEMSETTINGS.md) custom metadata types.

Once these steps have been completed, create `AsyncAction__c` records linked to your processor class via the `ProcessorClass__c` field. When run, the processor will process any `AsyncAction__c` records with a _Pending_ Status.

Once the action has been processed, the framework updates the `AsyncAction__c` record with details about its execution, including its _Status_, any errors that occurred, and if it needs to be retried.

Read more about the `AsyncAction__c` object [here](/docs/ASYNCACTIONOBJECT.md).
![An AsyncAction__c record](/media/sample_async_action.png)

Developers can track the status of their Actions through reports, list views, or through a custom "related list" component on records related to the Actions.
![Async Action List View](/media/list_view.png)

![The Async Action Related List Component](/media/related_list.png)

---

## Plugins

### Logging
By default, the framework will output details about its operations to traditional Salesforce debug logs via `System.debug()` calls. If desired, callers can instead publish logs via their tool of choice, by following these steps:

#### #1: Create an apex class which implements the `AsyncActionLogger.Adapter` interface, and hooks into your logging tool of choice.

This interface has two required methods:
- `void log(System.LoggingLevel level, Type loggedFromClass, Id relatedRecordId, Object logMessage)`
    - This method is called by the framework to record various log messages. Its parameters are as follows:
        - `System.LoggingLevel level`: The severity of the log message. 
        - `Type loggedFromClass`: The Apex Class that the message was logged from.
        - `Id relatedRecordId`: The Id of a Salesforce record that the log message pertains to.
        - `Object logMessage`: The message, or object (ie., Exception) to be logged. 
- `void save(Boolean publishImmediate)`
    - This method is called by the framework at the end of a transaction, to commit previously stored log messages to the database. Its `publishImmediate` Boolean flag should be used by frameworks which can optionally publish log messages via platform events, as it may help ensure logs are not lost in the wake of uncaught exceptions. 

Here's an example of a sample adapter which hooks into the [apex-logger](https://github.com/jasonsiders/apex-logger) framework:
```java
public class ApexLoggerAdapter implements AsyncActionLogger.Adapter {
    public void log(System.LoggingLevel level, Type loggedFrom, Id recordId, Object msg) {
        new Logger()?.setLoggedFrom(loggedFrom)?.setRelatedRecordId(recordId)?.log(level, msg);
    }

    public void save(Boolean publishImmediate) {
        Logger.LogPublisher publisher = (publishImmediate == true) 
            ? new LogEventPublisher()
            : new LogDmlPublisher();
        new Logger()?.publish(publisher);
    }
}
```

#### #2. Create an `AsyncActionGlobalSetting__mdt` record, and set the _Logger Adapter_ field to the name of your apex class.

Using the above example:
![An AsyncActionGlobalSetting__mdt Record](/media/sample_global_setting_record.png)

> _Note: If your org does not have a `AsyncActionGlobalSetting__mdt` record, or if the "Logger Adapter" is not a valid implementor of the `AsyncActionLogger.Adapter` interface, the framework will use the default logging mechanism instead, and log messages will continue to be published to traditional Salesforce debug logs._