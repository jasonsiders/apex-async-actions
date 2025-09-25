The **Init Async Action** invocable action initializes new async actions based on processor settings and input data. This action creates AsyncAction**c records that respect the configuration defined in AsyncActionProcessor**mdt settings.

## Purpose

This invocable action allows Flow users to create async actions programmatically while ensuring they are properly configured according to the processor settings. The created actions are initialized with "Pending" status and are ready for processing by the async actions framework.

## Input Parameters

| Parameter                                 | Data Type | Required | Description                                                                     |
| ----------------------------------------- | --------- | -------- | ------------------------------------------------------------------------------- |
| AsyncActionProcessor\_\_mdt DeveloperName | String    | Yes      | Developer name of the AsyncActionProcessor\_\_mdt record to use for this action |
| Data                                      | String    | No       | Optional data payload for the async action                                      |
| Related Record ID                         | Id        | No       | Optional ID of the record this async action is related to                       |

## Output

This invocable action returns a single AsyncAction\_\_c record that has been initialized with the provided parameters and processor settings.

## Usage in Flow

Use this action when you need to create async actions from within a Flow. The action will automatically apply the configuration from the specified processor settings, including retry counts and other processing parameters.
