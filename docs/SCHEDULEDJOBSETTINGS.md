# The `AsyncActionScheduledJob__mdt` Custom Metadata Type

This Custom Metadata Type is used to govern a single instance of the `AsyncActionSchedulable` scheduled job.

## Creating a Settings Record

Create a record for each scheduled job that you wish to have active at once. You may want multiple instances to run certain _Async Actions_ at different intervals. For example, time-sensitive Async Actions can be added to a job that kicks off every 2 minutes, while another job that runs hourly can handle menial background tasks.

Follow these steps to create a settings record for the scheduled job:

1. Navigating to _Setup > Custom Metadata > Async Action Scheduled Jobs > Manage_
2. If no records exist, click _New_ to create a new record.
3. Set the fields according to your preferences.
4. Click _Save_.

Once you've created a settings record for your scheduled job, you'll need to associate Async Actions to your scheduled job. Use the [`AsyncActionScheduledJobItem__mdt`](/docs/SCHEDULEDJOBITEMSETTINGS.md) junction object to accomplish this.

Each time an Async Action is inserted, or the scheduled job runs, code will run to ensure that each active scheduled job is running at the correct interval.

## Fields

![A "Async Action Scheduled Job" Custom Metadata record](/media/sample_scheduled_job_config.png)

- **Async Action Scheduled Job Name/Label**: (Text) Standard fields which serve as the API Name and friendly Label of the record. These do not impact anything.
- **Cron Expression**: (Text) Required when `Type` is "Custom". Contains a custom Cron Expression that is used to schedule the job. For example, `0 0 0 * * ?` schedules a job to run nightly at midnight.
- **Enabled**: (Checkbox) Determines whether an `AsyncActionSchedulable` job is enabled. When unchecked, records will not be processed via a scheduled job. This setting is enforced whenever the scheduled job runs, or an `AsyncAction__c` record is inserted.
- **Interval**: (Number) Required when `Type` is "Semi-Hourly". Determines the number of minutes that pass between instances of the scheduled job. Must be a valid number between 1-59. To run a job every 60 minutes, use an "Hourly" type-job instead. To run a custom schedule, use a "Custom" type-job instead.
- **Type**: (Picklist) Required. Indicates the type of scheduled job. Options include:
    - `Custom`: The job runs according to a custom cron expression.
    - `Hourly`: The job runs at the top of each hour.
    - `Semi-Hourly`: The job runs every X minutes.

> Read more about the `AsyncActionScheduledJobItem__mdt` Custom Metadata Type [here](/docs/SCHEDULEDJOBITEMSETTINGS.md)
> Read more about the `AsyncActionSchedulable` Job [here](/docs/ASYNCACTIONSCHEDULEDABLE.md)
