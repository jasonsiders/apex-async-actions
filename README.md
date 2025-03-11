# `apex-async-actions`

Welcome to `apex-async-actions`, a Salesforce platform tool designed to simplify and enhance asynchronous task management.

This tool empowers developers to create and manage custom asynchronous actions using Apex code, enhancing scalability and reliability for complex Salesforce orgs.

**Why?** As Salesforce orgs scale in size and complexity, asynchronous processing becomes increasingly crucial. Deferring critical business processes offers significant benefits, but it also introduces challenges such as difficult debugging, unexpected failures, and limited configurability.

`apex-async-actions` aims to mitigate these issues and simplify asynchronous processing. By tracking each operation instance as an `AsyncAction__c` record, developers can easily trigger, monitor, and troubleshoot their processes, or enable admins and stakeholders to do so independently.

The framework offers a range of configuration options, which allows developers to tailor various aspects of their asynchronous jobs:

-   **How/When Job is Triggered**: Define how your action processor should be initiated, and how often it should run.
-   **Batch Size**: Specify the number of records to process per invocation.
-   **Error Handling**: Determine if certain types of errors should be automatically retried.

## **Getting Started**

`apex-async-actions` is available as an **Unlocked** package. You can see the latest version of the package [**here**](https://github.com/jasonsiders/apex-async-actions/releases/latest).

Run this command to install the package, replacing `<<package_version_id>>` with the package version Id (starting with `04t`)

```sh
sf package install -p <<package_version_id>>
```

Once installed, assign the `AsyncActionAdministrator` permission set to yourself and any users who need access to view and edit `AsyncAction__c` records:

```sh
sf org assign permset -n AsyncActionAdministrator
```

---

## **Usage**

To properly use this framework, developers first define **_processors_**. Processors are asynchronous functions to be performed at some point in the future.

Once a processor is defined, developers can insert `AsyncAction__c` records linked to that processor, to invoke those functions against a set of Salesforce records and/or other data structures.

The boilerplate details of _when_, _how_, and _how often_ these functions run are all handled by the `AsyncActionProcessor__mdt` custom metadata type.

### Creating Processors

Creating a processor is a simple, two-step process:

#### 1. Define Your Processor Logic

Developers may choose to use an Apex Class, or a Flow to define their _processor_ logic:

<details>
    <summary><b>Using Apex</b></summary>

Create an Apex Class that implements the `AsyncActions.Processor` interface.

The framework will dynamically instantiate your processor type using `Type.forName`. For this reason, the class must also have a publicly visible, 0-argument constructor.

Example:

```java
public class FooProcessor implements AsyncActions.Processor {
    public void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
        // Create a Bar__c record for each Foo__c related to the given actions
        List<Bar__c> bars = new List<Bar__c>();
        for (AsyncAction__c action : actions) {
            Id fooId = (Id) action?.RelatedRecordId__c;
            Bar__c bar = new Bar__c(Foo__c = fooId);
            bars?.add(bar);
            // Mark the action as completed, assuming DML will succeed
            action.Status__c = AsyncActions.Status.COMPLETED.name();
        }
        // Attempt to insert the Bar__c records
        try {
            Database.insert(bars);
        } catch (Exception error) {
            // Failed to insert Bar__c records - mark the actions as failed
            new AsyncActions.Failure(settings)?.fail(actions, error);
        }
    }
}
```

Read more about the `AsyncActions.Processor` interface [here](/docs/ASYNCACTIONSPROCESSOR.md).

</details>

<details>
    <summary><b>Using Flow</b></summary>

Create a Flow to handle your processing logic. This flow should have the following inputs/outputs defined:

<table>
    <tr>
        <th>Input Name</th>
        <th>Data Type</th>
        <th>Available for Input</th>
        <th>Available for Output</th>
    </tr>
    <tr>
        <td><code>asyncAction</code></td>
        <td><code>AsyncAction__c</code></td>
        <td>Yes</td>
        <td>Yes</td>
    </tr>
    <tr>
        <td><code>settings</code></td>
        <td><code>AsyncActionProcessor__mdt</code></td>
        <td>Yes</td>
        <td>Optional</td>
    </tr>
</table>

Alternatively, you can clone the included [**Template Flow**](/force-app/main/default/flows/Template_Async_Action_Flow.flow-meta.xml), which conforms to this spec.

> **Note**: _Your flow can write logic specific to a single `AsyncAction__c` record. The framework uses Salesforce's [`Invocable.Actions`](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Invocable_Action.htm#apex_class_Invocable_Action) library to automatically bulkify the flows at runtime. This makes your async action flows safe, even when run against hundreds of `AsyncAction__c` records per batch._

Example:
![A Sample Async Actions Flow](/media/sample_flow.png)

</details>

Whether your processor logic resides in an Apex Class or a Flow, each should typically result in one of two outcomes:

-   If the logic was successfully processed, set the `AsyncAction__c` record(s)' _Status_ to "Completed"
-   Else, use handle any errors using the `AsyncActions.Failure` class, or the `Handle Async Action Failures` invocable method.

For more examples of both apex and flow processors, consult the [`/example-app`](/example-app/) directory.

#### 2. Create a Configuration Record

The `AsyncActionProcessor__mdt` custom metadata type record configures various aspects of your action, such as its _Batch Size_.

The record's _Processor_ should match the fully-qualified name of your Flow or Apex class. If this record is missing or invalid, your async action job will not run.

Example:
![An AsyncActionProcessor__mdt Record](/media/sample_processor_config.png)

To run your action immediately, set the _Run On Insert_ to `true`. An instance of the job will start shortly after corresponding Async Action record(s) are inserted.

To process accumulated actions (or retries) at regular intervals, use the `AsyncActionScheduledJob__mdt` and `AsyncActionScheduledJobItem__mdt` custom metadata types to automatically configure scheduled jobs. Read more about using these custom metadata types below:

-   [`AsyncActionScheduledJob__mdt`](/docs/SCHEDULEDJOBSETTINGS.md)
-   [`AsyncActionScheduledJobItem__mdt`](/docs/SCHEDULEDJOBITEMSETTINGS.md)

Read more about this custom metadata type [here](/docs/PROCESSORSETTINGS.md).

### Creating Async Action Records

Once these steps are complete, your processor is ready for use. Create _Async Action_ records linked to your processor, via the _Processor Name_ field. While these records may be inserted like any other custom object, developers may use `AsyncActions.initAction` method(s) or the `Init Async Action` invocable action to automatically generate actions that respect the current configuration for a given settings record.

When the `AsyncActionJob` runs, it will process any _Pending_ records with a matching _Processor Name_ value. Once the job finishes, the framework updates the record with execution details, including its _Status_, any errors, and retry information.

Read more about the `AsyncAction__c` object [here](/docs/ASYNCACTIONOBJECT.md).
![An AsyncAction__c record](/media/sample_async_action.png)

### Monitoring Actions

Developers can track the status of their actions through reports, list views, or a custom "related list" component on records related to the Actions.
![Async Action List View](/media/list_view.png)

![The Async Action Related List Component](/media/related_list.png)

---

## Plugins

Certain aspects of the framework have defined behavior that can be overridden by users through plugins. As the framework evolves, additional plugin options may be added to this section:

<details>
    <summary><h3>Logging</h3></summary>

By default, the framework outputs details about its operations to traditional Salesforce debug logs using `System.debug()` calls. To use a different logging mechanism, follow these steps:

#### 1. Create an Apex Class that implements `AsyncActionLogger.Adapter`

Your custom implementation will receive log messages from the framework and can be used to integrate with your preferred logging tool.

The `AsyncActionLogger.Adapter` interface requires the following two methods to be defined in your class:

```java
void log(System.LoggingLevel level, Object logMessage);
void save();
```

The `log` method is called by the framework to record various log messages. The `save` method is called by the framework at the end of a transaction to commit previously captured log messages to the database.

This sample adapter integrates with the [apex-logger](https://github.com/jasonsiders/apex-logger) framework:

```java
public class ApexLoggerAdapter implements AsyncActionLogger.Adapter {
    public void log(System.LoggingLevel level, Object msg) {
        new Logger()?.log(level, msg);
    }

    public void save() {
        new Logger()?.publish();
    }
}
```

#### 2. Set the `AsyncActionGlobalSetting__mdt.LoggerPlugin__c` field to the name of your Apex Class

If such a record does not exist, or if the specified _Logger Plugin_ does not implement the `AsyncActionLogger.Adapter` interface correctly, the framework will use the default logging mechanism instead.

Using the above example:
![An AsyncActionGlobalSetting__mdt Record](/media/sample_global_setting_record.png)

</summary>
