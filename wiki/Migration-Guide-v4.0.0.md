Starting in `v4.0.0`, the `AsyncActionGlobalSetting__mdt` custom metadata type has been replaced by [`AsyncActionParameter__mdt`](./The-AsyncActionParameter__mdt-Custom-Metadata-Type). This is a breaking change that affects anyone who has:

- Configured a logger plugin or a default delay via `AsyncActionGlobalSetting__mdt`
- Called `AsyncActionTestUtils.initGlobalSettings()` or `AsyncActionTestUtils.mockGlobalSettings()` in test code
- Referenced `AsyncActionGlobalSetting__mdt` in custom code

### Migration Steps

#### 1. Record your current settings

In `v3.x`, the framework read a **single** `AsyncActionGlobalSetting__mdt` record. Navigate to `Setup > Custom Metadata Types > Async Action Global Setting > Manage Records`, and note the values of these fields:

| Field               | Value                      |
| ------------------- | -------------------------- |
| `LoggerPlugin__c`   | Fully qualified class name |
| `DelayInMinutes__c` | Number of minutes          |

#### 2. Remove references to the old settings from your code

`v4.0.0` deletes `AsyncActionGlobalSetting__mdt`, `AsyncActionTestUtils.initGlobalSettings()`, and `AsyncActionTestUtils.mockGlobalSettings()`. Code that still references them will not compile against `v4.0.0`, and can cause the upgrade to fail.

Search your codebase for `AsyncActionGlobalSetting__mdt`, `initGlobalSettings`, and `mockGlobalSettings`, and remove those references before you upgrade. You'll replace them in step 5.

#### 3. Install `v4.0.0`

You can find instructions to install this package [**here**](https://github.com/jasonsiders/apex-async-actions/releases/tag/v4.0.0).

#### 4. Re-create your settings as parameters

In `v4.0.0`, each setting is its own `AsyncActionParameter__mdt` record, identified by its `DeveloperName`:

| DeveloperName    | Value                      |
| ---------------- | -------------------------- |
| `LoggerPlugin`   | Fully qualified class name |
| `DelayInMinutes` | Number of minutes          |

1. Navigate to `Setup > Custom Metadata Types > Async Action Parameter > Manage Records`
2. For each value you recorded in step 1, create a corresponding `AsyncActionParameter__mdt` record using the table above

#### 5. Update test code

In `v3.x`, tests that exercised logger plugins or delays used `AsyncActionTestUtils.initGlobalSettings()`:

```apex
// v3.x
AsyncActionGlobalSetting__mdt settings = AsyncActionTestUtils.initGlobalSettings();
settings.LoggerPlugin__c = 'MyLoggerAdapter';
settings.DelayInMinutes__c = 5;
```

In `v4.0.0`, use `AsyncActionTestUtils.mockParameter()`:

```apex
// v4.0.0
AsyncActionTestUtils.mockParameter('LoggerPlugin', 'MyLoggerAdapter');
AsyncActionTestUtils.mockParameter('DelayInMinutes', '5');
```

#### 6. Clean up

If the upgrade left `AsyncActionGlobalSetting__mdt` in your org as a deprecated component, delete it from `Setup > Custom Metadata Types`.

:tada: Congrats! If you made it this far, your installation has been successfully upgraded.
