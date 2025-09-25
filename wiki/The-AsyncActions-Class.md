The `AsyncActions` class serves as the central namespace and entry point for the async actions framework. It provides utility methods for creating async actions and contains essential inner classes and interfaces.

## Methods

### `initAction`

Creates a new AsyncAction\_\_c record configured with the specified processor settings and context information.

The framework provides multiple overloads to accommodate different initialization scenarios:

-   Full specification with processor settings, related record ID, and custom data
-   Using SObject references instead of Ids
-   Variations with or without custom data
-   Simple initialization with just processor settings

All overloads initialize the action with "Pending" status, set NextEligibleAt\_\_c to current time for immediate processing, and apply configuration from processor settings.
