# The `AsyncActionProcessor__mdt` Custom Metadata Type

This Custom Metadata Type is used to govern configuration behavior for a specific instance of the `AsyncActionProcessor`. The class that it controls is listed in the `ProcessorClass__c` field. A record of this type should be created for each `AsyncActionProcessor` class you create. If a matching record does not exist, the processor class will fail to run.

## Fields

![An Async Action Processor Record](/media/sample_processor_config.png)

-   **Async Action Processor Name/Label**: (Text) Standard fields which serve as the API Name and friendly Label of the record. Does not impact anything - call these whatever you want.
-   **Batch Size**: (Number) Controls the number of `AsyncAction__c` records that can be processed during a single queueable run. Adjust this to suit the Processor Class's specific use case. For example, if your Processor Class makes an HTTP Callout for each Async Action record, your batch size should be lower than 100, to accommodate Salesforce callout limits.
-   **Bypass Finalizer Retry Limit**: (Checkbox) Salesforce does not allow Finalizers to re-launch failed Queueable jobs more than 5 times in a row. When this box is checked, the framework will detect this error and instead launch a platform event. This in effect resets the limit, and allows the job to continue processing. When unchecked, 5 successive failed jobs will cause the entire process to abort.
-   **Enabled**: (Checkbox) Determines if the Processor Class is active. Unchecking this box will prevent it from running, even if it has associated pending `AsyncAction__c` records.
-   **Processor Class**: (Text) The fully-qualified API name of the `AsyncActionProcessor` class that this record controls, including namespace if available. This value is unique - there should only be one record per class.
-   **Retries**: (Number) Controls the number of times that a new `AsyncAction__c` record can be retried before being marked as _Failed_ when using `ALLOW_RETRIES` [error handling](/docs/ASYNCACTIONPROCESSOR.md#error-handling). This only applies to newly created records; updating this field will not trigger existing records to be updated.
-   **Retry Interval**: (Number) Controls the number of minutes in the future that an Async Action record will be scheduled to be retried. If 0, the record will be instantly retried at the conclusion of the current transaction.
-   **Run on Insert**: (Checkbox) Determines whether the current action will be launched when it is first inserted. Use this sparingly to minimize the number of asynchronous transactions. Where possible, leave this unchecked, and records will processed as part of a scheduled job instead.
