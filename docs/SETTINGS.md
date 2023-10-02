# The `AsyncActionSetting__mdt` Custom Metadata Type

This Custom Metadata Type is used to govern common behavior across the entire framework. There can only be 1 record of this type at any given time, and it must have a `DeveloperName` of _Default_.

## Creating a Settings Record
After installing `apex-async-actions` in a new environment, you must create a Settings record. Without this, the package will not function as intended. Follow these steps:
1. Manage Async Action Setting records, by navigating to _Setup > Custom Metadata > Async Action Settings > Manage_
2. If no records exist, click _New_ to create a new record.
3. Set the `Label` and `Async Action Settings Name` to _Default_, and adjust all other fields according to your preferences.
4. Click _Save_. 

## Fields

![An Async Action Settings Record](/media/sample_settings.png)

-   **Async Action Setting Name/Label**: (Text) Standard fields which serve as the API Name and friendly Label of the record. The Label does not impact anything, but the `Async Action Name` must be _Default_.
-   **Run Scheduled Job**: (Checkbox) Determines whether an `AsyncActionSchedulable` job is enabled. When unchecked, records will not be processed via a scheduled job. This setting is enforced whenever the scheduled job runs, or an `AsyncAction__c` record is inserted. If disabled, any instances of the scheduled job are aborted. If enabled, duplicate instances of the scheduled job are aborted. If no instances of the job exist, one is created.
-   **Scheduled Job Interval**: (Number) Determines the number of minutes that pass between instances of the scheduled job. Must be a valid number between 1-60.

> Read more about the `AsyncActionSchedulable` Job [here](/docs/SCHEDULEDJOB.md)
> As the framework evolves, it may host other fields in the future.
