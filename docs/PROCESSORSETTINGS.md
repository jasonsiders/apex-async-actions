# The `AsyncActionProcessor__mdt` Custom Metadata Type

This Custom Metadata Type is used to govern configuration behavior for a specific instance of the `AsyncActionJob`. The class that it controls is listed in the `Processor__c` field. A record of this type should be created for each `AsyncActionJob` class you create. If a matching record does not exist, the processor class will fail to run.

## Fields

![An Async Action Processor Record](/media/sample_processor_config.png)

-   **Async Action Processor Name/Label**: (Text) Standard fields which serve as the API Name and friendly Label of the record. Does not impact anything - call these whatever you want.
-   **Batch Size**: (Number) Controls the number of `AsyncAction__c` records that can be processed during a single queueable run. Adjust this to suit the Processor Class's specific use case. For example, if your Processor Class makes an HTTP Callout for each Async Action record, your batch size should be lower than 100, to accommodate Salesforce callout limits.
-   **Enabled**: (Checkbox) Determines if the Processor Class is active. Unchecking this box will prevent it from running, even if it has associated pending `AsyncAction__c` records.
-   **Max Stack Depth**: (Number) The maximum number of times that this job can be chained before terminating. This is used to prevent runaway jobs.
-   **Processor**: (Text) The fully-qualified API name of an Apex Class which implements `AsyncActions.Processor`, or a flow which extends the `Template_Async_Action_Flow`. This value is unique - there should only be one record per class/flow.
-   **Retries**: (Number) Controls the number of times that a new `AsyncAction__c` record can be retried before being marked as _Failed_ when using `ALLOW_RETRIES` [error handling](/docs/ASYNCACTIONPROCESSOR.md#error-handling). This only applies to newly created records; updating this field will not trigger existing records to be updated.
-   **Retry Interval**: (Number) Controls the number of minutes in the future that an Async Action record will be scheduled to be retried. If 0, the record will be instantly retried at the conclusion of the current transaction.
-   **Run on Insert**: (Checkbox) Determines whether the current action will be launched when it is first inserted. Use this sparingly to minimize the number of asynchronous transactions. Where possible, leave this unchecked, and records will processed as part of a scheduled job instead.
