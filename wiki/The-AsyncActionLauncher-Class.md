The `AsyncActionLauncher` class is responsible for constructing and launching AsyncActionJob queueables. It provides methods to launch processing jobs for processors that have pending AsyncAction\_\_c records, with built-in duplicate prevention and queueable limits validation.

## Methods

### `launch`

Launches AsyncActionJob queueables for processors that have pending actions.

-   `Map<String, Id> launch(List<AsyncActionProcessor__mdt> settingsList)`
-   `Id launch(AsyncActionProcessor__mdt settings)`

### `launchAll`

Launches AsyncActionJob queueables for all available processor configurations.

-   `Map<String, Id> launchAll()`

## Usage

```apex
// Launch jobs for specific processors
AsyncActionLauncher launcher = new AsyncActionLauncher();
List<AsyncActionProcessor__mdt> processors = [SELECT DeveloperName FROM AsyncActionProcessor__mdt WHERE Enabled__c = true];
Map<String, Id> jobIds = launcher.launch(processors);

// Launch job for a single processor
AsyncActionProcessor__mdt settings = AsyncActionProcessorService.get('MyProcessor');
Id jobId = launcher.launch(settings);

// Launch jobs for all processors
Map<String, Id> allJobIds = launcher.launchAll();
```
