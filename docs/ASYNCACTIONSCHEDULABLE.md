# The `AsyncActionSchedulable` Class

By default, `AsyncActionProcessor` classes are launched by a scheduled apex class, `AsyncActionSchedulable`. The enablement and frequency of this job are controlled by the [`AsyncActionScheduledJob__mdt`](/docs/ASYNCACTIONSCHEDULEDJOB.md) Custom Metadata Type. The actions launched by each job are controlled by the [`AsyncActionScheduledJobItem__mdt`](/docs/ASYNCACTIONSCHEDULEDJOBITEM.md) Custom Metadata Type. 

## Process Overview

The `AsyncActionSchedulable` follows this general process in a `System.Schedulable` context:

- Checks if the job is enabled, via `AsyncActionSetting__mdt.Enabled__c`. 
  - If `Enabled__c` is false, the job does not launch any `AsyncActionProcessor` jobs, and future runs are aborted.
  - If `Enabled__c` is true, the job does the following:
    - The job publishes an `AsyncActionStart__e` platform event.
    - The platform event evaluates whether there are any valid `AsyncAction__c` records to be processed, and if so, it dispatches the corresponding `AsyncActionProcessor` job(s) to process them.
        - The platform event will only evaluate the `AsyncActionProcessor` classes linked to the current job via the `AsyncActionScheduledJobItem__mdt` junction object.
    - Once complete, the job aborting the current instance and rescheduling it for a certain number of minutes in the future. This interval is governed by the `AsyncActionScheduledJob__mdt.Interval__c` field.

## Best Practices

-   Do not manually schedule or abort this job. Instead, control its enablement and frequency through the [`AsyncActionScheduledJob__mdt`](/docs/ASYNCACTIONSCHEDULEDJOB.md) custom metadata type. The framework includes code which "enforces" proper running of this class.
