# The `AsyncActionScheduledJobItem__mdt` Custom Metadata Type

The `AsyncActionScheduledJobItem__mdt` can be used to relate a specific [`AsyncActionProcessor__mdt`](/docs/ASYNCACTIONPROCESSOR.md) record to a specific [`AsyncActionScheduledJob__mdt`](/docs/SCHEDULEDJOBSETTINGS.md) record. This junction object could be leveraged to relate a many _Async Actions_ to many _Scheduled Jobs_.

## Creating a Settings Record

Create a record for each _Async Action_ that you wish to add to a specific scheduled job.

Follow these steps to create a a `AsyncActionScheduledJobItem__mdt` record:

1. Navigating to _Setup > Custom Metadata > Async Action Scheduled Job Items > Manage_
2. If no records exist, click _New_ to create a new record.
3. Set the fields according to your preferences.
4. Click _Save_.

## Fields

![A "Async Action Scheduled Job Item" Custom Metadata record](/media/sample_scheduled_job_item.png)

-   **Async Action Scheduled Job Name/Label**: (Text) Standard fields which serve as the API Name and friendly Label of the record. These do not impact anything.
-   **Enabled**: (Checkbox) Determines whether an `AsyncActionSchedulable` job is enabled. When unchecked, records will not be processed via a scheduled job. This setting is enforced whenever the scheduled job runs, or an `AsyncAction__c` record is inserted.
-   **Async Action**: (Lookup: `AsyncActionProcessor__mdt`) _Required_. Configuration record for the `AsyncActionProcessor` class that should be run.
-   **Enabled**: (Checkbox) Controls the enablement of the Action on the Scheduled Job. Allows for individual Actions to be disabled.
-   **Scheduled Job**: (Lookup: `AsyncActionScheduledJob__mdt`) _Required_. Configuration record for the `AsyncActionSchedulable` job that should host the action.

> Read more about the `AsyncActionProcessor__mdt` Custom Metadata Type [here](/docs/ASYNCACTIONPROCESSOR.md)
> Read more about the `AsyncActionScheduledJob__mdt` Custom Metadata Type [here](/docs/SCHEDULEDJOBSETTINGS.md)
> Read more about the `AsyncActionSchedulable` Job [here](/docs/ASYNCACTIONSCHEDULEDABLE.md)
