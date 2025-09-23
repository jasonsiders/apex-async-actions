The `AsyncActionStart__e` platform event provides a mechanism for triggering async action processing from external systems or through event-driven architectures.

## Overview

AsyncActionStart is a custom platform event that enables event-driven processing of async actions. It allows external systems, other Salesforce orgs, or automated processes to trigger async action processing without direct database access.

## Purpose and Usage

The platform event supports:

1. **External Integration** - Allow external systems to trigger async processing
2. **Event-Driven Architecture** - React to business events with async processing
3. **Cross-Org Communication** - Trigger processing from other Salesforce orgs
4. **Bulk Action Creation** - Create multiple async actions from a single event
5. **Decoupled Triggering** - Separate action creation from action processing

## Field Reference

| Field API Name | Label   | Data Type      | Required | Description                                       |
| -------------- | ------- | -------------- | -------- | ------------------------------------------------- |
| `Actions__c`   | Actions | Long Text Area | Yes      | JSON array of async actions to create and process |

## Field Details

### Actions\_\_c

Contains a JSON array of async action definitions. Each action object in the array should include:

**Required Properties:**

-   `processorName` - DeveloperName of the AsyncActionProcessor\_\_mdt
-   `relatedRecordId` - Id of the related Salesforce record (optional)
-   `data` - Custom data for the action (optional)

**Example JSON Structure:**

```json
[
	{
		"processorName": "Account_Followup_Processor",
		"relatedRecordId": "001000000000001",
		"data": "{\"priority\": \"High\", \"dueDate\": \"2024-01-15\"}"
	},
	{
		"processorName": "Lead_Scoring_Processor",
		"relatedRecordId": "00Q000000000002",
		"data": "{\"source\": \"Web\", \"score\": 85}"
	}
]
```

## Event Publishing

### From Apex

```apex
List<AsyncActionStart__e> events = new List<AsyncActionStart__e>();

// Create actions for multiple processors
List<Object> actions = new List<Object>();
actions.add(new Map<String, Object>{
    'processorName' => 'Account_Followup_Processor',
    'relatedRecordId' => accountId,
    'data' => JSON.serialize(customData)
});

AsyncActionStart__e event = new AsyncActionStart__e(
    Actions__c = JSON.serialize(actions)
);
events.add(event);

// Publish the event
EventBus.publish(events);
```

### From Flow

Use the "Publish Platform Event" Flow element:

1. Select `AsyncActionStart__e` as the platform event
2. Set the `Actions__c` field with properly formatted JSON
3. Connect to your flow logic

### From External Systems

Use the Salesforce REST API:

```http
POST /services/data/v58.0/sobjects/AsyncActionStart__e/
Content-Type: application/json
Authorization: Bearer {access_token}

{
  "Actions__c": "[{\"processorName\":\"My_Processor\",\"relatedRecordId\":\"001XX0000000001\"}]"
}
```

## Event Consumption

The framework automatically subscribes to AsyncActionStart events through the `AsyncActionStartTriggerHandler`:

### Processing Flow

1. **Event Reception** - Platform event trigger fires
2. **JSON Parsing** - Actions array is deserialized
3. **Action Creation** - AsyncAction\_\_c records are created
4. **Validation** - Processor names and data are validated
5. **Processing Trigger** - Actions are queued for processing (if RunOnInsert is enabled)

### Error Handling

The event handler includes robust error handling:

-   **Invalid JSON** - Malformed Actions\_\_c content is logged and skipped
-   **Missing Processors** - References to non-existent processors are logged
-   **DML Failures** - Individual action creation failures don't affect others
-   **Bulk Operations** - All valid actions are processed even if some fail

## Usage Patterns

### External System Integration

```javascript
// External system publishes event
const eventData = {
	Actions__c: JSON.stringify([
		{
			processorName: "Order_Processing",
			relatedRecordId: orderRecord.Id,
			data: JSON.stringify({
				orderTotal: 1500.0,
				priority: "Standard"
			})
		}
	])
};

// POST to Salesforce platform event endpoint
fetch("/services/data/v58.0/sobjects/AsyncActionStart__e/", {
	method: "POST",
	headers: {
		"Content-Type": "application/json",
		Authorization: `Bearer ${accessToken}`
	},
	body: JSON.stringify(eventData)
});
```

### Cross-Org Communication

```apex
// In source org - publish event
AsyncActionStart__e event = new AsyncActionStart__e(
    Actions__c = JSON.serialize(new List<Object>{
        new Map<String, Object>{
            'processorName' => 'Data_Sync_Processor',
            'relatedRecordId' => recordId,
            'data' => JSON.serialize(syncData)
        }
    })
);
EventBus.publish(event);

// In target org - automatic consumption via trigger
```

### Batch Event Processing

```apex
// Create multiple actions from business logic
List<Object> bulkActions = new List<Object>();

for (Account acc : highValueAccounts) {
    bulkActions.add(new Map<String, Object>{
        'processorName' => 'VIP_Account_Processor',
        'relatedRecordId' => acc.Id,
        'data' => JSON.serialize(new Map<String, Object>{
            'tier' => 'Platinum',
            'lastActivity' => acc.LastActivityDate
        })
    });
}

// Single event for multiple actions
AsyncActionStart__e event = new AsyncActionStart__e(
    Actions__c = JSON.serialize(bulkActions)
);
EventBus.publish(event);
```

## Best Practices

### Event Design

1. **Batch Actions** - Include multiple actions in a single event when possible
2. **Validate JSON** - Ensure Actions\_\_c contains valid JSON before publishing
3. **Handle Failures** - Design external systems to handle event publishing failures
4. **Monitor Volume** - Track event publishing rates and platform event limits

### Data Structure

1. **Consistent Format** - Standardize JSON structure across all event publishers
2. **Required Fields** - Always include processorName at minimum
3. **Data Validation** - Validate custom data structure before serialization
4. **Size Limits** - Keep Actions\_\_c under platform event size limits

### Error Handling

1. **Graceful Degradation** - Handle individual action failures without stopping others
2. **Logging Strategy** - Log both successful and failed action creations
3. **Retry Logic** - Implement retry logic in external systems if needed
4. **Monitoring** - Set up alerts for high failure rates

### Performance Considerations

1. **Event Limits** - Respect Salesforce platform event publishing limits
2. **Bulk Processing** - Process multiple actions per event
3. **Async Benefits** - Leverage the asynchronous nature of platform events
4. **Governor Limits** - Consider DML limits when creating many actions

## Monitoring and Troubleshooting

### Platform Event Monitoring

```sql
-- Check recent platform events
SELECT Id, CreatedDate, CreatedById, Actions__c
FROM AsyncActionStart__e
WHERE CreatedDate >= YESTERDAY
ORDER BY CreatedDate DESC
```

### Event Processing Status

Monitor the `AsyncActionStartTriggerHandler` execution through:

-   Debug logs for event processing
-   AsyncAction\_\_c record creation patterns
-   Framework logging (if custom logger is configured)

### Common Issues

**Events Not Processing:**

-   Verify platform event trigger is active
-   Check event JSON format in Actions\_\_c field
-   Review debug logs for parsing errors
-   Confirm processor names exist and are spelled correctly

**Partial Action Creation:**

-   Review individual action validation in debug logs
-   Check for missing required processor configurations
-   Verify related record IDs are valid
-   Monitor DML limit usage during bulk operations

**Performance Problems:**

-   Monitor event publishing frequency vs. platform limits
-   Check for large Actions\_\_c payloads causing timeouts
-   Review async action processing capacity
-   Consider breaking large event payloads into smaller ones

### Debug Techniques

**Test Event Publishing:**

```apex
// Test event creation and publishing
List<Object> testActions = new List<Object>{
    new Map<String, Object>{
        'processorName' => 'Test_Processor',
        'relatedRecordId' => Test.getTestId(Account.SObjectType),
        'data' => '{"test": true}'
    }
};

AsyncActionStart__e testEvent = new AsyncActionStart__e(
    Actions__c = JSON.serialize(testActions)
);

Test.startTest();
EventBus.publish(testEvent);
Test.stopTest();

// Verify async actions were created
List<AsyncAction__c> createdActions = [
    SELECT ProcessorName__c, RelatedRecordId__c, Data__c
    FROM AsyncAction__c
    WHERE ProcessorName__c = 'Test_Processor'
];
System.debug('Created ' + createdActions.size() + ' actions');
```

## Security Considerations

### Access Control

-   Platform event publishing requires appropriate permissions
-   Consider field-level security for sensitive data in Actions\_\_c
-   External systems need valid authentication to publish events

### Data Protection

-   Avoid including sensitive data in Actions\_\_c field
-   Use RelatedRecordId\_\_c to reference detailed data instead
-   Consider encryption for sensitive data payloads

## Related Components

-   [AsyncAction\_\_c](AsyncAction Custom Object) - Records created from events
-   [AsyncActionProcessor\_\_mdt](AsyncActionProcessor Custom Metadata Type) - Referenced processor configurations

## See Also

-   [Platform Events Documentation](https://developer.salesforce.com/docs/atlas.en-us.platform_events.meta/platform_events/) - Salesforce platform event fundamentals
