The `AsyncActionAdministrator` permission set provides comprehensive access to async action framework objects, metadata, and administrative functions.

## Overview

The AsyncActionAdministrator permission set is designed for users who need to configure, monitor, and troubleshoot async action processing. This includes system administrators, developers, and operations teams.

## Included Permissions

### Object Permissions

#### AsyncAction\_\_c

```
Object Settings:
- Read: ✓
- Create: ✓
- Edit: ✓
- Delete: ✓
- View All: ✓
- Modify All: ✓
```

**Field Permissions:**

-   All fields: Read and Edit access
-   Sensitive fields secured through additional mechanisms

#### Custom Metadata Types

Access to configuration metadata:

-   `AsyncActionProcessor__mdt` - Full access
-   `AsyncActionProcessorSettings__mdt` - Full access
-   `ProcessorPlugin__mdt` - Full access
-   `ProcessorScheduleConfig__mdt` - Full access

### System Permissions

#### Apex Class Access

```
- AsyncActions: Execute
- AsyncActionJob: Execute
- AsyncActionLauncher: Execute
- AsyncActionSchedulable: Execute
- AsyncActionFlowProcessor: Execute
- AsyncActionLogger: Execute
- All processor implementations: Execute
```

#### Administrative Permissions

```
- Manage Users: ✓ (for permission set assignment)
- View Setup and Configuration: ✓
- Customize Application: ✓
- Modify Metadata Through Metadata API Functions: ✓
- API Enabled: ✓
```

## Assignment Guidelines

### Target Roles

#### System Administrators

Full permission set for complete framework management:

```apex
// Assign to system administrators
PermissionSetAssignment adminAssignment = new PermissionSetAssignment(
    AssigneeId = systemAdminUserId,
    PermissionSetId = getAsyncActionAdminPermissionSetId()
);
insert adminAssignment;
```

#### Operations Team

Limited assignment for monitoring and troubleshooting:

```apex
// Create custom permission set for operations
PermissionSet opsPermissionSet = new PermissionSet(
    Name = 'AsyncActionOperations',
    Label = 'Async Action Operations'
);
insert opsPermissionSet;

// Grant read access to monitoring objects
ObjectPermissions monitoringPerms = new ObjectPermissions(
    ParentId = opsPermissionSet.Id,
    SObjectType = 'AsyncAction__c',
    PermissionsRead = true,
    PermissionsViewAllRecords = true
);
insert monitoringPerms;
```

### Assignment Automation

```apex
public class PermissionSetManager {
	public static void assignAsyncActionPermissions(Id userId, String role) {
		Id permissionSetId = getPermissionSetId(role);

		// Check if already assigned
		List<PermissionSetAssignment> existing = [
			SELECT Id
			FROM PermissionSetAssignment
			WHERE AssigneeId = :userId AND PermissionSetId = :permissionSetId
		];

		if (existing.isEmpty()) {
			PermissionSetAssignment assignment = new PermissionSetAssignment(
				AssigneeId = userId,
				PermissionSetId = permissionSetId
			);
			insert assignment;
		}
	}

	private static Id getPermissionSetId(String role) {
		String permissionSetName = getPermissionSetNameForRole(role);
		PermissionSet ps = [
			SELECT Id
			FROM PermissionSet
			WHERE Name = :permissionSetName
			LIMIT 1
		];
		return ps.Id;
	}
}
```

## Security Model

### Object-Level Security

The permission set provides comprehensive object access while respecting organizational security:

```apex
// Permission set respects sharing rules
List<AsyncAction__c> visibleActions = [
    SELECT Id, ProcessorName__c, Status__c
    FROM AsyncAction__c
    WITH SHARING  // Respects user's record access
];
```

### Field-Level Security

Sensitive fields require additional protection:

```apex
public class SecureFieldAccess {
    public static Boolean hasFieldAccess(String objectName, String fieldName) {
        Schema.DescribeFieldResult fieldDescribe =
            Schema.getGlobalDescribe()
                  .get(objectName)
                  .getDescribe()
                  .fields
                  .getMap()
                  .get(fieldName)
                  .getDescribe();

        return fieldDescribe.isAccessible();
    }

    public static List<AsyncAction__c> getSecureActions() {
        // Query with field-level security
        return [
            SELECT Id, ProcessorName__c, Status__c,
                   CASE WHEN $Profile.Name = 'System Administrator'
                        THEN ActionData__c
                        ELSE NULL END ActionData__c
            FROM AsyncAction__c
            WHERE isAccessible()
        ];
    }
}
```

## Administrative Functions

### User Access Management

Monitor and manage user access to the framework:

```apex
public class AccessAuditor {
	public static List<User> getAsyncActionUsers() {
		return [
			SELECT Id, Name, Profile.Name, LastLoginDate
			FROM User
			WHERE
				Id IN (
					SELECT AssigneeId
					FROM PermissionSetAssignment
					WHERE PermissionSet.Name = 'AsyncActionAdministrator'
				)
				AND IsActive = TRUE
		];
	}

	public static void auditAccess() {
		List<PermissionSetAssignment> assignments = [
			SELECT AssigneeId, Assignee.Name, PermissionSet.Name, CreatedDate
			FROM PermissionSetAssignment
			WHERE PermissionSet.Name LIKE 'AsyncAction%'
			ORDER BY CreatedDate DESC
		];

		for (PermissionSetAssignment assignment : assignments) {
			System.debug('User: ' + assignment.Assignee.Name + ' has permission set: ' + assignment.PermissionSet.Name);
		}
	}
}
```

### Delegation Patterns

Implement secure delegation for specific operations:

```apex
public class SecureDelegation {
	@InvocableMethod(label='Launch Processor' description='Launches async processor with security checks')
	public static void launchProcessorSecurely(List<LaunchRequest> requests) {
		for (LaunchRequest request : requests) {
			// Verify user has permission to launch this processor
			if (hasLaunchPermission(request.processorName)) {
				AsyncActionLauncher.launch(request.processorName);
			} else {
				throw new SecurityException('Insufficient permissions to launch: ' + request.processorName);
			}
		}
	}

	public class LaunchRequest {
		@InvocableVariable(required=true)
		public String processorName;
	}

	private static Boolean hasLaunchPermission(String processorName) {
		// Check custom permission or processor-specific access
		return FeatureManagement.checkPermission('Launch_' + processorName) ||
			FeatureManagement.checkPermission('AsyncActionAdministrator');
	}
}
```

## Monitoring and Compliance

### Access Logging

Track administrative actions:

```apex
public class AdminActionLogger {
	public static void logAdminAction(String action, String details) {
		AdminAuditLog__c log = new AdminAuditLog__c(
			Action__c = action,
			Details__c = details,
			UserId__c = UserInfo.getUserId(),
			Username__c = UserInfo.getName(),
			Timestamp__c = DateTime.now(),
			SessionId__c = UserInfo.getSessionId()
		);
		insert log;
	}

	public static void auditProcessorAccess(String processorName) {
		logAdminAction('PROCESSOR_ACCESS', 'Accessed processor: ' + processorName);
	}

	public static void auditConfigurationChange(String configType, String details) {
		logAdminAction('CONFIG_CHANGE', configType + ': ' + details);
	}
}
```

### Compliance Reports

Generate compliance and access reports:

```apex
public class ComplianceReporting {
	public static void generateAccessReport() {
		// Get all users with async action access
		List<User> adminUsers = getAsyncActionUsers();

		// Generate permission summary
		Map<String, List<String>> permissionSummary = new Map<String, List<String>>();

		for (User user : adminUsers) {
			List<PermissionSetAssignment> userPerms = [
				SELECT PermissionSet.Name
				FROM PermissionSetAssignment
				WHERE AssigneeId = :user.Id AND PermissionSet.Name LIKE 'AsyncAction%'
			];

			List<String> permissions = new List<String>();
			for (PermissionSetAssignment perm : userPerms) {
				permissions.add(perm.PermissionSet.Name);
			}

			permissionSummary.put(user.Name, permissions);
		}

		// Generate report (implementation depends on reporting needs)
		generatePermissionReport(permissionSummary);
	}
}
```

## Troubleshooting Permission Issues

### Common Permission Problems

#### Missing Object Access

```apex
public class PermissionDiagnostics {
	public static void diagnoseObjectAccess(Id userId, String objectName) {
		// Check object permissions
		List<ObjectPermissions> objPerms = [
			SELECT PermissionsRead, PermissionsCreate, PermissionsEdit
			FROM ObjectPermissions
			WHERE
				SObjectType = :objectName
				AND ParentId IN (
					SELECT PermissionSetId
					FROM PermissionSetAssignment
					WHERE AssigneeId = :userId
				)
		];

		if (objPerms.isEmpty()) {
			System.debug('No object permissions found for user');
		} else {
			for (ObjectPermissions perm : objPerms) {
				System.debug(
					'Read: ' +
						perm.PermissionsRead +
						', Create: ' +
						perm.PermissionsCreate +
						', Edit: ' +
						perm.PermissionsEdit
				);
			}
		}
	}

	public static void diagnoseFieldAccess(Id userId, String objectName, String fieldName) {
		Schema.DescribeFieldResult fieldDescribe = Schema.getGlobalDescribe()
			.get(objectName)
			.getDescribe()
			.fields
			.getMap()
			.get(fieldName)
			.getDescribe();

		System.debug('Field accessible: ' + fieldDescribe.isAccessible());
		System.debug('Field updateable: ' + fieldDescribe.isUpdateable());
		System.debug('Field createable: ' + fieldDescribe.isCreateable());
	}
}
```

#### Sharing Rule Conflicts

```apex
public class SharingDiagnostics {
	public static void diagnoseSharingAccess(Id userId, Id recordId) {
		// Check if user can access specific record
		List<UserRecordAccess> access = [
			SELECT RecordId, HasReadAccess, HasEditAccess, HasDeleteAccess
			FROM UserRecordAccess
			WHERE UserId = :userId AND RecordId = :recordId
		];

		if (!access.isEmpty()) {
			UserRecordAccess recordAccess = access[0];
			System.debug(
				'Record access - Read: ' +
					recordAccess.HasReadAccess +
					', Edit: ' +
					recordAccess.HasEditAccess +
					', Delete: ' +
					recordAccess.HasDeleteAccess
			);
		}
	}
}
```

## Best Practices

### Permission Set Management

1. **Principle of Least Privilege** - Grant minimum necessary permissions
2. **Regular Audits** - Review and audit permission assignments quarterly
3. **Role-Based Assignment** - Assign based on job function, not individual requests
4. **Documentation** - Document all permission assignments and changes

### Security Considerations

1. **Sensitive Data** - Additional protection for sensitive fields
2. **API Access** - Monitor API usage by admin users
3. **Session Management** - Implement session timeout policies
4. **Change Tracking** - Log all administrative changes

### Operational Excellence

1. **Automated Assignment** - Use automation for standard role assignments
2. **Delegation** - Implement secure delegation patterns
3. **Monitoring** - Real-time monitoring of administrative actions
4. **Compliance** - Regular compliance reporting and reviews

## See Also

-   [Security Model Overview](./Security-Model-Overview) - Framework security architecture
-   [AsyncAction Custom Object](./AsyncAction-Custom-Object) - Object structure and security
-   [AsyncActionProcessor Custom Metadata Type](./AsyncActionProcessor-Custom-Metadata-Type) - Configuration security
