The `AsyncActions` class serves as the central namespace and entry point for the async actions framework. It provides utility methods for creating async actions and contains essential inner classes and interfaces.

## Overview

As an abstract global class, `AsyncActions` acts as a pseudo-namespace providing a organized location for all framework types and methods. It's the primary class developers interact with when creating async actions.

## Methods

### `initAction`

Creates a new AsyncAction\_\_c record configured with the specified processor settings and context information.

The framework provides multiple overloads to accommodate different initialization scenarios:

-   Full specification with processor settings, related record ID, and custom data
-   Using SObject references instead of Ids
-   Variations with or without custom data
-   Simple initialization with just processor settings

All overloads initialize the action with "Pending" status, set NextEligibleAt\_\_c to current time for immediate processing, and apply configuration from processor settings.

## Inner Classes and Interfaces

### `AsyncActions.Failure`

See [AsyncActions.Failure Class](./AsyncActions.Failure-Class) for complete documentation.

### `AsyncActions.Processor`

See [AsyncActions.Processor Interface](./AsyncActions.Processor-Interface) for complete documentation.

### `AsyncActions.RetryBehavior`

See [AsyncActions.RetryBehavior Enum](./AsyncActions.RetryBehavior-Enum) for complete documentation.

### `AsyncActions.Status`

See [AsyncActions.Status Enum](./AsyncActions.Status-Enum) for complete documentation.

## See Also

-   [Creating-Your-First-Processor](./Creating-Your-First-Processor) - Step-by-step processor development
-   [Core-Concepts](./Core-Concepts) - Framework architecture and patterns
