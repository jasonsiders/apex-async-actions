# `apex-async-actions`

Async Actions uses the power of the Salesforce platform to make it easier to launch, process, and track business-critical asynchronous tasks. Developers can define your own custom _Actions_ through Apex code, and then control and monitor its execution with declarative tools.

## Why?
As Salesforce orgs grow in size and complexity, the need for asynchronous processing grows in importance. While there is much to be gained from deferring critical business processes, perils await those who do so carelessly, including painful debugging, sudden, unexplained failures, and a lack of configurability.

`apex-async-actions` hopes to address many of these concerns, and to make asynchronous processing easier. 

By tracking each instance of an operation as an `AsyncAction__c` record, developers can quickly trigger, track and troubleshoot their operations, or empower their admins and stakeholders to do so themselves.

A suite of configuration options allows developers to customize many aspects of their asynchronous jobs:

- **How should the job be triggered?** 
- **How many records should the job process per invocation?**
- **Should certain types of failures be automatically retried?**

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

To use this framework, developers start by building their own "actions" - logic contained in an apex class. After some light configuration, admins can invoke 

### Creating Action Processors

Developers can create a new _Action_ processor in three easy steps:

#### 1. Create an Apex Class that extends `AsyncActionProcessor`
This defines what the Action will do when it runs. Here's an example:

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

Read more about the `AsyncActionProcessor` class [here](/docs/ASYNCACTIONPROCESSOR.md).

#### 2. Create a Corresponding `AsyncActionProcessor__mdt` Record

This custom metadata type record can be used to configure certain aspects of your action; for example, its _Batch Size_. The record's _Processor Class_ should match the fully-qualified name of your apex class. If such a record does not exist, your async action job will not run. 

Here's an example processor record:
   ![An AsyncActionProcessor__mdt Record](/media/sample_processor_config.png)

Read more about this custom metadata type [here](/docs/PROCESSORSETTINGS.md).

#### 3. Define How/When Your Job Will Run

If you wish to run your action immediately, set `AsyncActionProcessor__mdt.RunOnInsert__c` to _true_. An instance of the job will launch shortly after corresponding `AsyncAction__c` record(s) are inserted.

If you wish to process accumulated actions (or retries) at a regular scheduled interval, using the [`AsyncActionScheduledJob__mdt`](/docs/SCHEDULEDJOBSETTINGS.md) and [`AsyncActionScheduledJobItem__mdt`](/docs/SCHEDULEDJOBITEMSETTINGS.md) custom metadata types.

#### 4. Create Async Action Records
Once these steps have been completed, your framework is ready for primetime! Create `AsyncAction__c` records linked to your processor class via the _Processor Class_ field. These _Async Action_ records can be created just like any other custom object, via Flows, Apex, or in the UI. 

When a given processor runs, it will process any `AsyncAction__c` records with a matching _Processor Class_ value and a "Pending" _Status_.

Once the action has been processed, the framework updates the `AsyncAction__c` record with details about its execution, including its _Status_, any errors that occurred, and if it needs to be retried.

Read more about the `AsyncAction__c` object [here](/docs/ASYNCACTIONOBJECT.md).
![An AsyncAction__c record](/media/sample_async_action.png)

#### 5. Monitor Actions
Developers can track the status of their actions through reports, list views, or through a custom "related list" component on records related to the Actions.
![Async Action List View](/media/list_view.png)

![The Async Action Related List Component](/media/related_list.png)

---

## Plugins

Certain aspects of the framework have defined behavior that can be overridden by users through plugins. As time goes on, more plugin options may be added to the section below:

### Logging
By default, the framework will output details about its operations to traditional Salesforce debug logs via `System.debug()` calls. If desired, callers can instead publish logs via their tool of choice, by following these steps:

#### 1. Create an Apex Class that implements `AsyncActionLogger.Adapter`

 Your own custom implementation will receive log messages from the framework, and can be used to hook into your logging tool of choice.

The `AsyncActionLogger.Adapter` interface has two methods which must be defined in your class:
```java
void log(
    System.LoggingLevel level, 
    Type loggedFromClass, 
    Id relatedRecordId, 
    Object logMessage
);
```
This method is called by the framework to record various log messages.
- `System.LoggingLevel level`: The severity of the log message. 
- `Type loggedFromClass`: The Apex Class that the message was logged from.
- `Id relatedRecordId`: The Id of a Salesforce record that the log message pertains to. 
- `Object logMessage`: The message, or object (ie., Exception) to be logged. 
```java
void save(Boolean publishImmediate);
```
This method is called by the framework at the end of a transaction, to commit previously stored log messages to the database. 
- `Boolean publishImmediate`: Indicates to loggers if 

---

Here's a sample adapter, which hooks into the [apex-logger](https://github.com/jasonsiders/apex-logger) framework:

```java
public class ApexLoggerAdapter implements AsyncActionLogger.Adapter {
    public void log(
        System.LoggingLevel level, 
        Type loggedFrom, 
        Id recordId, 
        Object msg
    ) {
        new Logger()
            ?.setLoggedFrom(loggedFrom)
            ?.setRelatedRecordId(recordId)
            ?.log(level, msg);
    }

    public void save(Boolean publishImmediate) {
        Logger.LogPublisher publisher = (publishImmediate == true) 
            ? new LogEventPublisher()
            : new LogDmlPublisher();
        new Logger()?.publish(publisher);
    }
}
```

#### 2. Set the `AsyncActionGlobalSetting__mdt.LoggerAdapter__c` field to the name of your apex class.

**Note**: This package does not ship with a record of this custom  metadata type by default. 

If such a record does not exist, or if the specified _Logger Adapter_ is not a valid implementor of the `AsyncActionLogger.Adapter` interface, the framework will use the default logging mechanism instead. 

Using the above example:
![An AsyncActionGlobalSetting__mdt Record](/media/sample_global_setting_record.png)