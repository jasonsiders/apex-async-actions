The `AsyncActionAdministrator` permission set provides access to async action framework objects for users who need to monitor, retry, and manually intervene with async actions.

## Overview

**Important**: This permission set is NOT needed for end users to trigger or execute async actions. It is only required for people who need to monitor, retry, and manually intervene with async action processing.

## Included Permissions

### Object Permissions

#### AsyncAction\_\_c

Users will have read/edit access to all fields on the AsyncAction\_\_c object.

### Custom Metadata Types

Access to configuration metadata:

-   `AsyncActionProcessor__mdt` - Read access
-   `AsyncActionGlobalSetting__mdt` - Read access
-   `AsyncActionScheduledJob__mdt` - Read access
-   `AsyncActionScheduledJobItem__mdt` - Read access

## Assignment Guidelines

Assign this permission set to:

-   System administrators who manage the async actions framework
-   Operations team members who monitor async action processing
-   Support users who need to troubleshoot failed actions
-   Developers who need to test and debug async action processors

## See Also

-   [AsyncAction Custom Object](./AsyncAction-Custom-Object) - Object structure and fields
-   [Getting Started](./Getting-Started) - Framework installation and setup
