# The `AsyncActionSchedulable` Class

By default, `AsyncActionProcessor` classes are launched by a scheduled job: `AsyncActionSchedulable`. The enablement and frequency of this job are controlled by the [`AsyncActionSetting__mdt`](/docs/SETTINGS.md) custom metadata type.

## Process Overview

The `AsyncActionSchedulable` follows this general process in a `System.Schedulable` context:

1. Checks if the job is enabled, via `AsyncActionSetting__mdt.RunScheduledJob__c`. If `RunScheduledJob__c` is not enabled, the job does not launch any `AsyncActionProcessor` jobs, and future runs are aborted.
2. If `RunScheduledJob__c` is enabled, it publishes an `AsyncActionStart__e` platform event. This event evaluates whether there are any valid `AsyncAction__c` records to be processed, and if so, it dispatches the corresponding `AsyncActionProcessor` job(s) to process them.
3. If `RunScheduledJob__c` is enabled, it finishes by aborting the current instance and rescheduling it for a certain number of minutes in the future. This interval is governed by the `AsyncActionSetting__mdt.ScheduledJobInterval__c` field.

## Best Practices

-   Do not manually schedule or abort this job. Instead, control its enablement and frequency through the [`AsyncActionSetting__mdt`](/docs/SETTINGS.md) custom metadata type. The framework includes code which "enforces" proper running of this class. Only one instance of this job may exist at any given time, and only if the job is enabled (via `AsyncActionSetting__mdt.RunScheduledJob__c`).
