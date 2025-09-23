# AsyncActionAdministrator Permission Set

The `AsyncActionAdministrator` permission set grants comprehensive access to all async actions framework objects and functionality. It's designed for users who need to manage, monitor, and troubleshoot async action operations.

## Overview

This permission set provides the necessary permissions for users to work with async actions in both administrative and operational capacities. It includes full CRUD access to async action objects and visibility into framework operations.

## Who Should Receive This Permission Set

### Primary Recipients

-   **System Administrators** - Full framework management and troubleshooting
-   **Developers** - Building and testing async action processors
-   **Operations Teams** - Monitoring and managing async action processing
-   **Business Process Owners** - Configuring and overseeing business-specific processors

### Secondary Recipients

-   **Support Staff** - Investigating async action issues
-   **Data Analysts** - Creating reports on async action performance
-   **Integration Specialists** - Managing external system integrations

## Included Permissions

### Object Permissions

#### AsyncAction\_\_c

| Permission             | Access Level | Description                                   |
| ---------------------- | ------------ | --------------------------------------------- |
| **Read**               | ✓            | View async action records and their details   |
| **Create**             | ✓            | Create new async action records               |
| **Edit**               | ✓            | Modify existing async action records          |
| **Delete**             | ✓            | Remove async action records                   |
| **View All Records**   | ✓            | See all async actions across the org          |
| **Modify All Records** | ✓            | Edit any async action regardless of ownership |

### Field-Level Permissions

#### AsyncAction\_\_c Fields

| Field API Name       | Read | Edit | Description                             |
| -------------------- | ---- | ---- | --------------------------------------- |
| `Data__c`            | ✓    | ✓    | Custom data payload for processors      |
| `Error__c`           | ✓    | ✓    | Error details from failed processing    |
| `RelatedRecordId__c` | ✓    | ✓    | ID of related Salesforce record         |
| `RelatedRecord__c`   | ✓    | ✗    | Formula field linking to related record |
| `Retries__c`         | ✓    | ✓    | Number of retry attempts remaining      |

### Tab Visibility

#### AsyncAction\_\_c Tab

-   **Visibility:** Available
-   **Description:** Provides access to async action list views and record management

## Assignment Instructions

### For Administrators

**Salesforce CLI:**

```sh
sf org assign permset -n AsyncActionAdministrator -o username@company.com
```

**Salesforce UI:**

1. Navigate to **Setup → Users → Permission Sets**
2. Click on **AsyncActionAdministrator**
3. Click **Manage Assignments**
4. Click **Add Assignments**
5. Select target users and click **Assign**

### Bulk Assignment

For multiple users, create a CSV file and use Data Loader or similar tools:

```csv
Username,PermissionSetName
user1@company.com,AsyncActionAdministrator
user2@company.com,AsyncActionAdministrator
```

## Security Model

### Access Philosophy

The permission set follows a \"full access\" model for async actions, based on the principle that users managing async operations need comprehensive visibility and control.

### Security Considerations

#### Data Sensitivity

-   **Custom Data** - Users can view Data\_\_c fields which may contain sensitive information
-   **Error Details** - Error\_\_c fields may expose system internals
-   **Related Records** - RelatedRecordId\_\_c provides visibility into business record associations

#### Operational Security

-   **Modify All Records** - Users can edit any async action regardless of creator
-   **Delete Access** - Users can remove async action records and their audit trail
-   **Cross-Object Visibility** - Related record access depends on user's permissions to those objects

### Mitigation Strategies

#### For Sensitive Environments

1. **Custom Permission Set** - Create a restricted version with read-only access
2. **Field-Level Security** - Apply additional FLS restrictions to sensitive fields
3. **IP Restrictions** - Limit access to trusted network locations
4. **Login Hours** - Restrict access to business hours if appropriate

#### Data Protection

1. **Audit Trail** - Monitor permission set assignments and usage
2. **Regular Review** - Periodically review who has the permission set
3. **Principle of Least Privilege** - Only assign to users who need full access
4. **Documentation** - Maintain records of why each user needs this access

## Common Use Cases

### System Administrators

```
Tasks:
- Configure AsyncActionProcessor__mdt records
- Monitor overall framework performance
- Troubleshoot failed async actions
- Manage scheduled job configurations

Required Permissions:
- Full CRUD on AsyncAction__c
- Access to Setup areas for metadata configuration
- View All/Modify All for cross-team troubleshooting
```

### Developers

```
Tasks:
- Test processor implementations
- Debug async action failures
- Create test data for development
- Monitor processing during development cycles

Required Permissions:
- Full CRUD on AsyncAction__c
- Ability to create test actions
- Access to error details for debugging
```

### Operations Teams

```
Tasks:
- Monitor daily async action volumes
- Investigate processing delays
- Manage failed action retries
- Generate operational reports

Required Permissions:
- Read access to all async actions
- Edit access for manual retry/cancellation
- View all records for comprehensive monitoring
```

## Permission Set Alternatives

### Read-Only Alternative

For users who only need monitoring access:

```
Custom Permission Set: "AsyncActionViewer"
Object Permissions:
- AsyncAction__c: Read, View All Records
Field Permissions:
- All fields: Read only
Tab Settings:
- AsyncAction__c: Available
```

### Limited Administrative Access

For business process owners:

```
Custom Permission Set: "AsyncActionBusinessUser"
Object Permissions:
- AsyncAction__c: Read, Create, Edit (not Delete)
Field Permissions:
- Data__c: Read/Edit (for business configuration)
- Error__c: Read only
- RelatedRecordId__c: Read/Edit
- Retries__c: Read/Edit (for business retry decisions)
```

## Troubleshooting Permission Issues

### User Cannot See Async Actions Tab

**Check:**

1. Permission set assignment is active
2. User profile allows custom tabs
3. App contains the AsyncAction tab
4. Tab visibility is set correctly in permission set

### User Cannot View Async Action Records

**Check:**

1. Object-level permissions are correct
2. Sharing rules don't restrict access
3. Field-level security allows access to key fields
4. Organization-wide defaults are appropriate

### User Cannot Edit Async Actions

**Check:**

1. Edit permission is granted on AsyncAction\_\_c object
2. Field-level permissions allow editing
3. Record isn't locked by workflow or approval process
4. User has appropriate profile permissions

## Monitoring Permission Usage

### Audit Queries

```sql
-- Find users with the permission set
SELECT Assignee.Name, Assignee.Username, AssignedDate
FROM PermissionSetAssignment
WHERE PermissionSet.Name = 'AsyncActionAdministrator'
ORDER BY AssignedDate DESC

-- Check recent async action access
SELECT Username, Action, CreatedDate
FROM SetupAuditTrail
WHERE Section = 'Manage Users'
  AND Display LIKE '%AsyncActionAdministrator%'
  AND CreatedDate >= LAST_N_DAYS:30
```

### Login History Analysis

Monitor for unusual access patterns:

-   Off-hours access to async action records
-   Bulk data downloads from async action objects
-   Repeated failed login attempts

## Best Practices

### Assignment Management

1. **Regular Reviews** - Quarterly review of permission set assignments
2. **Documentation** - Maintain business justification for each assignment
3. **Automation** - Use provisioning workflows for standard role assignments
4. **Deactivation Process** - Remove permissions when users change roles

### Security Hygiene

1. **Least Privilege** - Start with minimal permissions and add as needed
2. **Temporary Access** - Use time-limited assignments for contractors
3. **Monitoring** - Set up alerts for permission set changes
4. **Training** - Ensure users understand their responsibilities

### Operational Excellence

1. **Standard Assignments** - Define which roles automatically get this permission set
2. **Exception Process** - Clear process for non-standard permission requests
3. **Audit Trail** - Maintain records of permission changes and rationale
4. **Business Continuity** - Ensure multiple users can manage async actions

## Related Security Components

-   [AsyncActionGlobalSetting\_\_mdt](./Object-AsyncActionGlobalSetting) - Framework-wide security settings
-   [AsyncActionProcessor\_\_mdt](./Object-AsyncActionProcessor) - Processor-specific configurations
-   [Platform Event Security](./Object-AsyncActionStart) - AsyncActionStart\_\_e event permissions

## See Also

-   [Getting Started](./Getting-Started) - Initial setup including permission assignment
-   [Monitoring and Troubleshooting](./Monitoring-and-Troubleshooting) - Operational guidance for permission set holders
-   [Best Practices](./Best-Practices) - Framework security and operational best practices
