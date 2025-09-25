Guide to monitoring async action processing and troubleshooting common issues.

## Monitoring and Reporting

### List Views

The framework includes several pre-built list views for monitoring async actions:

-   **All Actions** - Complete view of all AsyncAction records
-   **Recent Actions** - Actions created in the last 7 days
-   **Failed Actions** - Actions that have permanently failed
-   **Pending Actions** - Actions awaiting processing

### Viewing Async Action Records

Navigate to the **Async Actions** tab to view and manage async action records. Each record displays:

-   Processing status and timestamps
-   Related record information
-   Error messages and retry counts
-   Processor configuration details

### Related List Component

Use the included Lightning component to display related actions on record pages. This allows you to see all async actions associated with a specific record.

### Reports and Dashboards

Create custom reports to monitor:

-   Processing success rates by processor
-   Average processing times
-   Error patterns and trends
-   Action volume over time

## Troubleshooting Common Issues

### Actions Stuck in "Pending" Status

**Causes:**

-   Processor metadata record is disabled
-   Processor class doesn't exist or has compilation errors
-   Missing permissions for the automated process user

**Solutions:**

1. Verify processor metadata is enabled
2. Check processor class compilation
3. Review debug logs for errors

### High Failure Rates

**Causes:**

-   Network connectivity issues
-   Data validation failures
-   Governor limit exceptions

**Solutions:**

1. Review error messages in failed action records
2. Adjust batch sizes for governor limit issues
3. Implement proper error handling in processors

### Poor Performance

**Causes:**

-   Inefficient batch sizes
-   Non-selective SOQL queries
-   Excessive DML operations

**Solutions:**

1. Tune batch sizes based on processor requirements
2. Optimize SOQL queries with proper WHERE clauses
3. Use bulk DML patterns

## Monitoring Queries

### Recent Failed Actions

```soql
SELECT Id, Status__c, Error__c, ProcessorName__c, CreatedDate
FROM AsyncAction__c
WHERE Status__c = 'Failed'
  AND CreatedDate >= LAST_N_DAYS:7
```

### Pending Actions by Processor

```soql
SELECT ProcessorName__c, COUNT(Id) ActionCount
FROM AsyncAction__c
WHERE Status__c = 'Pending'
GROUP BY ProcessorName__c
```

### Processing Success Rate

```soql
SELECT ProcessorName__c, Status__c, COUNT(Id) ActionCount
FROM AsyncAction__c
WHERE CreatedDate >= LAST_N_DAYS:30
GROUP BY ProcessorName__c, Status__c
```

## See Also

-   [AsyncAction Custom Object](./AsyncAction-Custom-Object) - Object structure and fields
-   [Best Practices](./Best-Practices) - Framework best practices
-   [Error Handling and Retry Logic](./Error-Handling-and-Retry-Logic) - Error handling patterns
