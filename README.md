# `apex-async-actions`

Async Actions uses the power of the Salesforce platform to make it easier to launch, process, and track business-critical asynchronous tasks. Developers can define your own custom _Actions_ through Apex code, and then control and monitor its execution with declarative tools.

## **Usage**

Developers can create a new _Action_ in two easy steps:

1. Create an Apex Class that extends the `AsyncActionProcessor` class. This defines what the Action will do when it runs.

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

2. Create a `AsyncActionProcessor__mdt` custom metadata record related to the class. This can be used to configure certain aspects of the Action; for example, its _Batch Size_. Read more about this custom metadata type [here](/docs/PROCESSORMETADATA.md).
   ![An AsyncActionProcessor__mdt Record](/media/sample_processor_config.png)

3. Define how you want your action to be launched. 
- Run your action near-immediately, set `AsyncActionProcessor__mdt.RunOnInsert__c` to _true_. An instance of the job will launch shortly after corresponding `AsyncAction__c` record(s) are inserted.
- Add your action at a regular scheduled interval, using the [`AsyncActionScheduledJob__mdt`](/docs/ASYNCACTIONSCHEDULEDJOB.md) and [`AsyncActionScheduledJobItem__mdt`](/docs/ASYNCACTIONSCHEDULEDJOBITEM.md) custom metadata types. 

Once the action has been processed, the framework updates the `AsyncAction__c` record with details about its execution, including its _Status_, if it needs to be retried, and logs (including errors) related to the Action.

Read more about the `AsyncAction__c` object [here](/docs/ASYNCACTION.md).
![An AsyncAction__c record](/media/sample_async_action.png)

Developers can track the status of their Actions through reports, list views, or through a custom "related list" component on records related to the Actions.
![Async Action List View](/media/list_view.png)

![The Async Action Related List Component](/media/related_list.png)

---

## **Getting Started**

`apex-async-actions` is available as an Unlocked package. Follow these instructions to get started.

### Install Dependencies

`apex-async-actions` uses the `lwc-related-list` package to display Action records in the UI, and the `apex-logger` package for logging.
You must install the latest version of each of these packages before installing `apex-async-actions`:

You can view the latest versions of these packages below:

-   [lwc-related-list](https://github.com/jasonsiders/lwc-related-list/releases/latest)
-   [apex-logger](https://github.com/jasonsiders/apex-logger/releases/latest)

Run this sfdx command to install each dependent package, using the package's `04t...` Id in place of `PACKAGE_VERSION_ID`:

```
sfdx package install -p PACKAGE_VERSION_ID
```

### Install/Deploy the Package

To use Async Actions in your own project, install the latest version of the package. You can find this version [here](https://github.com/jasonsiders/apex-async-actions/releases/latest).

Run this command to install the package, using the package's `04t...` Id in place of `PACKAGE_VERSION_ID`:

```
sfdx package install -p PACKAGE_VERSION_ID
```

Alternatively, if you wish to contribute to this project, you can deploy its contents directly to your org. To do this, clone the repo and then run `sfdx force source push`.

### Assign Permissions

You should assign the `AsyncActionAdministrator` permission set to yourself, along with any user that needs access to view and edit `AsyncAction__c` records. See Salesforce's [documentation](https://help.salesforce.com/s/articleView?id=sf.perm_sets_mass_assign.htm&type=5) for details.

### Enable Logging

This framework uses the `apex-logger` package to post logs related to the execution of Async Actions. When properly configured, these logs will be visible from the Async Action record page.

Enable logging by creating an org-wide default `LogSetting__c` custom settings record:

-   Navigate to _Setup > Custom Settings > Log Setting > Manage_.
-   Above _Default Organization Level Value_, click **_New_**.
-   Set _Enabled_ to `true`, and _Threshold_ to `INFO`.

> Note: Async Actions always run as the `Automated Process` user, which doesn't appear in Custom Settings' `User` lookup. For this reason, use the org-wide default Log Settings record to govern log visibility for Async Actions, or use an anonymous apex script to create a `LogSetting__c` record for this user.

Read more about `apex-logger` [here](https://github.com/jasonsiders/apex-logger).
