# `apex-async-actions`

Welcome to `apex-async-actions`, a Salesforce platform tool designed to simplify and enhance asynchronous task management. This tool empowers developers to create and manage custom asynchronous actions using Apex code, enhancing scalability and reliability for complex Salesforce orgs.

## Why?

As Salesforce orgs scale in size and complexity, asynchronous processing becomes increasingly crucial. Deferring critical business processes offers significant benefits, but it also introduces challenges such as difficult debugging, unexpected failures, and limited configurability.

`apex-async-actions` aims to mitigate these issues and simplify asynchronous processing. By tracking each operation instance as an `AsyncAction__c` record, developers can easily trigger, monitor, and troubleshoot their processes, or enable admins and stakeholders to do so independently.

A range of configuration options allows developers to tailor various aspects of their asynchronous jobs:

-   **How/When Job is Triggered**: Define how your action processor should be initiated, and how often it should run.
-   **Batch Size**: Specify the number of records to process per invocation.
-   **Error Handling**: Determine if certain types of errors should be automatically retried.

## **Getting Started**

`apex-async-actions` is available as an Unlocked package. Follow these instructions to get started.

### Install/Deploy the Package

To use Async Actions in your project, install the latest version of the package from [here](https://github.com/jasonsiders/apex-async-actions/releases/latest).

Run this command to install the package, replacing `<<package_version_id>>` with the package version Id (starting with `04t`)

```
sf package install -p <<package_version_id>>
```

### Assign Permissions

Assign the `AsyncActionAdministrator` permission set to yourself and any users who need access to view and edit `AsyncAction__c` records:

```
sf org assign permset -n AsyncActionAdministrator
```

## **Usage**

To use this framework, developers should first create their own "actions" as logic contained in an Apex class. After some light configuration, these actions can be invoked by inserting _Async Action_ records that reference the processor/Apex class.

### Creating Action Processors

Developers can define a new action in

#### 1. Create an Apex Class that extends `AsyncActionJob`

This defines what the Action will do when it runs. Here's an example:

```java
global class FooCreator extends AsyncActionJob {
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

Read more about the `AsyncActionJob` class [here](/docs/ASYNCACTIONPROCESSOR.md).

#### 2. Create a Corresponding `AsyncActionProcessor__mdt` Record

This custom metadata type record configures aspects of your action, such as its _Batch Size_. The record's _Processor Class_ should match the fully-qualified name of your Apex class. If this record is missing, your async action job will not run.

Here's an example processor record:
![An AsyncActionProcessor__mdt Record](/media/sample_processor_config.png)

Read more about this custom metadata type [here](/docs/PROCESSORSETTINGS.md).

#### 3. Define How/When Your Job Will Run

To run your action immediately, set the _Run On Insert_ to `true`. An instance of the job will start shortly after corresponding Async Action record(s) are inserted.

To process accumulated actions (or retries) at regular intervals, use the `AsyncActionScheduledJob__mdt` and `AsyncActionScheduledJobItem__mdt` custom metadata types to automatically configure scheduled jobs. Read more about using these custom metadata types below:

-   [`AsyncActionScheduledJob__mdt`](/docs/SCHEDULEDJOBSETTINGS.md)
-   [`AsyncActionScheduledJobItem__mdt`](/docs/SCHEDULEDJOBITEMSETTINGS.md)

### Creating Async Action Records

Once these steps are complete, your framework is ready for use. Create _Async Action_ records linked to your processor class via the _Processor Class_ field. These records can be created through Flows, Apex, or the UI, like any other custom object.

When a processor runs, it will process any _Pending_ records with a matching _Processor Class_ value. Once the job finishes, the framework updates the record with execution details, including its _Status_, any errors, and retry information.

Read more about the `AsyncAction__c` object [here](/docs/ASYNCACTIONOBJECT.md).
![An AsyncAction__c record](/media/sample_async_action.png)

### Monitoring Actions

Developers can track the status of their actions through reports, list views, or a custom "related list" component on records related to the Actions.
![Async Action List View](/media/list_view.png)

![The Async Action Related List Component](/media/related_list.png)

## Plugins

Certain aspects of the framework have defined behavior that can be overridden by users through plugins. As the framework evolves, additional plugin options may be added to this section:

### Logging

By default, the framework outputs details about its operations to traditional Salesforce debug logs using `System.debug()` calls. To use a different logging mechanism, follow these steps:

#### 1. Create an Apex Class that implements `AsyncActionLogger.Adapter`

Your custom implementation will receive log messages from the framework and can be used to integrate with your preferred logging tool.

The `AsyncActionLogger.Adapter` interface requires the following two methods to be defined in your class:

```java
void log(
    System.LoggingLevel level,
    Object logMessage
);
```

This method is called by the framework to record various log messages.

-   `System.LoggingLevel level`: The severity of the log message.
-   `Object logMessage`: The message or object (e.g., Exception) to be logged.

```java
void save(Boolean publishImmediate);
```

This method is called by the framework at the end of a transaction to commit previously stored log messages to the database.

-   `Boolean publishImmediate`: Indicates whether the messages should be saved immediately using a [platform event](https://developer.salesforce.com/docs/atlas.en-us.platform_events.meta/platform_events/platform_events_publish_apex.htm) with `Publish Immediately` save behavior, if possible. This ensures that errors are logged even if uncaught exceptions occur.

Here's a sample adapter that integrates with the [apex-logger](https://github.com/jasonsiders/apex-logger) framework:

```java
public class ApexLoggerAdapter implements AsyncActionLogger.Adapter {
    public void log(System.LoggingLevel level, Object msg) {
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

#### 2. Set the `AsyncActionGlobalSetting__mdt.LoggerPlugin__c` field to the name of your Apex class.

If such a record does not exist, or if the specified _Logger Plugin_ does not implement the `AsyncActionLogger.Adapter` interface correctly, the framework will use the default logging mechanism instead.

Using the above example:
![An AsyncActionGlobalSetting__mdt Record](/media/sample_global_setting_record.png)
