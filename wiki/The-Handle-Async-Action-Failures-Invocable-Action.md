The **Handle Async Action Failures** invocable action processes failure handling for async actions according to their retry configuration. This action applies the appropriate retry behavior and updates the action's status and retry count in memory.

## Purpose

This invocable action allows Flow users to handle async action failures while respecting the retry configuration defined in the AsyncActionProcessor\_\_mdt settings. It applies the specified retry behavior to determine whether the action should be retried, kept alive for indefinite retries, or marked as permanently failed.

## Input Parameters

| Parameter                                 | Data Type        | Required | Description                                                                                            |
| ----------------------------------------- | ---------------- | -------- | ------------------------------------------------------------------------------------------------------ |
| AsyncAction\_\_c Record                   | AsyncAction\_\_c | Yes      | The AsyncAction\_\_c record that failed and needs failure handling                                     |
| AsyncActionProcessor\_\_mdt DeveloperName | String           | Yes      | Developer name of the AsyncActionProcessor\_\_mdt record that defines the retry behavior               |
| Error Message                             | String           | Yes      | Error message describing what went wrong during action processing                                      |
| Retry Behavior                            | String           | No       | Name of the retry behavior to use. Valid values: "ALLOW_RETRY" (default), "KEEP_ALIVE", "SUDDEN_DEATH" |

## Output

This invocable action does not return any values. It modifies the provided AsyncAction\_\_c record in memory by updating its status and retry count based on the specified retry behavior.

## Usage in Flow

Use this action when an async action fails in your Flow and you want the failure handling to respect the processor's retry configuration. The action will automatically apply the appropriate retry logic based on the retry behavior specified.
