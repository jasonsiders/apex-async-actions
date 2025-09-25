The `AsyncActionScheduledJobItem__mdt` custom metadata type links individual processors to scheduled jobs, defining which async action processors should be executed when a scheduled job runs.

## Overview

AsyncActionScheduledJobItem records create the association between scheduled jobs and processors. Each record represents a single processor that will be launched when its parent scheduled job executes.

## Purpose and Usage

Scheduled job items provide:

1. **Processor Association** - Link specific processors to scheduled jobs
2. **Selective Execution** - Enable/disable individual processors within a schedule
3. **Flexible Grouping** - Organize processors into logical scheduling groups
4. **Execution Control** - Fine-tune which processors run when

## Field Reference

| Field API Name            | Label                  | Data Type             | Required | Description                                            |
| ------------------------- | ---------------------- | --------------------- | -------- | ------------------------------------------------------ |
| `DeveloperName`           | API Name               | Text(40)              | Yes      | Unique identifier for the scheduled job item           |
| `MasterLabel`             | Label                  | Text(40)              | Yes      | Human-readable name for the item                       |
| `ScheduledJob__c`         | Scheduled Job          | Metadata Relationship | Yes      | Reference to AsyncActionScheduledJob\_\_mdt            |
| `AsyncActionProcessor__c` | Async Action Processor | Metadata Relationship | Yes      | Reference to AsyncActionProcessor\_\_mdt               |
| `Enabled__c`              | Enabled                | Checkbox              | No       | Controls whether this processor runs with the schedule |
