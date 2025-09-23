Advanced plugin architecture for extending async action functionality with custom behaviors, middleware, and integration patterns.

## Overview

The plugin framework enables extensible async action processing through configurable middleware components, custom behaviors, and integration hooks. This allows organizations to customize framework behavior without modifying core components.

## Plugin Architecture

### Plugin Interface

```apex
global interface AsyncActionPlugin {
	void beforeProcess(PluginContext context);
	void afterProcess(PluginContext context);
	void onFailure(PluginContext context);
	Boolean isEnabled(AsyncActionProcessor__mdt settings);
}
```

### Plugin Context

```apex
global class PluginContext {
	public AsyncActionProcessor__mdt settings { get; private set; }
	public List<AsyncAction__c> actions { get; private set; }
	public Exception lastException { get; private set; }
	public Map<String, Object> customData { get; private set; }

	public PluginContext(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
		this.settings = settings;
		this.actions = actions;
		this.customData = new Map<String, Object>();
	}

	public void setException(Exception e) {
		this.lastException = e;
	}

	public void setCustomData(String key, Object value) {
		this.customData.put(key, value);
	}

	public Object getCustomData(String key) {
		return this.customData.get(key);
	}
}
```

## Core Plugin Types

### Audit Plugin

Track all processing activities:

```apex
global class AuditPlugin implements AsyncActionPlugin {
	public void beforeProcess(PluginContext context) {
		AsyncActionAudit__c audit = new AsyncActionAudit__c(
			ProcessorName__c = context.settings.DeveloperName,
			ActionsCount__c = context.actions.size(),
			StartTime__c = DateTime.now(),
			Phase__c = 'Before Process'
		);
		insert audit;

		context.setCustomData('auditId', audit.Id);
	}

	public void afterProcess(PluginContext context) {
		Id auditId = (Id) context.getCustomData('auditId');
		AsyncActionAudit__c audit = new AsyncActionAudit__c(
			Id = auditId,
			EndTime__c = DateTime.now(),
			Phase__c = 'After Process',
			Status__c = 'Completed'
		);
		update audit;
	}

	public void onFailure(PluginContext context) {
		Id auditId = (Id) context.getCustomData('auditId');
		AsyncActionAudit__c audit = new AsyncActionAudit__c(
			Id = auditId,
			EndTime__c = DateTime.now(),
			Phase__c = 'Failure',
			Status__c = 'Failed',
			ErrorMessage__c = context.lastException?.getMessage()
		);
		update audit;
	}

	public Boolean isEnabled(AsyncActionProcessor__mdt settings) {
		return settings.EnableAudit__c == true;
	}
}
```

### Metrics Plugin

Collect performance metrics:

```apex
global class MetricsPlugin implements AsyncActionPlugin {
	public void beforeProcess(PluginContext context) {
		context.setCustomData('startTime', System.currentTimeMillis());
		context.setCustomData('startCpuTime', Limits.getCpuTime());
	}

	public void afterProcess(PluginContext context) {
		Long startTime = (Long) context.getCustomData('startTime');
		Integer startCpuTime = (Integer) context.getCustomData('startCpuTime');

		ProcessingMetrics__c metrics = new ProcessingMetrics__c(
			ProcessorName__c = context.settings.DeveloperName,
			ActionsProcessed__c = context.actions.size(),
			WallClockTime__c = System.currentTimeMillis() - startTime,
			CpuTime__c = Limits.getCpuTime() - startCpuTime,
			DmlStatements__c = Limits.getDmlStatements(),
			SoqlQueries__c = Limits.getQueries(),
			Timestamp__c = DateTime.now()
		);
		insert metrics;
	}

	public void onFailure(PluginContext context) {
		// Record failure metrics
		afterProcess(context);
	}

	public Boolean isEnabled(AsyncActionProcessor__mdt settings) {
		return settings.EnableMetrics__c == true;
	}
}
```

### Rate Limiting Plugin

Implement processing rate limits:

```apex
global class RateLimitPlugin implements AsyncActionPlugin {
	public void beforeProcess(PluginContext context) {
		String processorName = context.settings.DeveloperName;
		Integer rateLimit = (Integer) context.settings.RateLimit__c;

		if (rateLimit != null && rateLimit > 0) {
			Integer recentProcessing = getRecentProcessingCount(processorName);

			if (recentProcessing >= rateLimit) {
				throw new RateLimitException('Rate limit exceeded: ' + recentProcessing + '/' + rateLimit);
			}
		}
	}

	public void afterProcess(PluginContext context) {
		// No action needed
	}

	public void onFailure(PluginContext context) {
		// No action needed
	}

	public Boolean isEnabled(AsyncActionProcessor__mdt settings) {
		return settings.RateLimit__c != null && settings.RateLimit__c > 0;
	}

	private Integer getRecentProcessingCount(String processorName) {
		List<AggregateResult> results = [
			SELECT COUNT(Id) processed
			FROM AsyncAction__c
			WHERE
				ProcessorName__c = :processorName
				AND Status__c = 'Completed'
				AND LastModifiedDate >= :DateTime.now().addMinutes(-1)
		];

		return (Integer) results[0].get('processed');
	}
}
```

## Plugin Manager

### Registration and Execution

```apex
global class PluginManager {
	private static Map<String, List<AsyncActionPlugin>> pluginRegistry = new Map<String, List<AsyncActionPlugin>>();

	static {
		initializePlugins();
	}

	public static void registerPlugin(String processorName, AsyncActionPlugin plugin) {
		if (!pluginRegistry.containsKey(processorName)) {
			pluginRegistry.put(processorName, new List<AsyncActionPlugin>());
		}
		pluginRegistry.get(processorName).add(plugin);
	}

	public static void executeBeforeProcess(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
		String processorName = settings.DeveloperName;
		List<AsyncActionPlugin> plugins = getEnabledPlugins(processorName, settings);

		PluginContext context = new PluginContext(settings, actions);

		for (AsyncActionPlugin plugin : plugins) {
			try {
				plugin.beforeProcess(context);
			} catch (Exception e) {
				System.debug('Plugin error in beforeProcess: ' + e.getMessage());
				// Continue with other plugins
			}
		}
	}

	public static void executeAfterProcess(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
		String processorName = settings.DeveloperName;
		List<AsyncActionPlugin> plugins = getEnabledPlugins(processorName, settings);

		PluginContext context = new PluginContext(settings, actions);

		for (AsyncActionPlugin plugin : plugins) {
			try {
				plugin.afterProcess(context);
			} catch (Exception e) {
				System.debug('Plugin error in afterProcess: ' + e.getMessage());
			}
		}
	}

	public static void executeOnFailure(
		AsyncActionProcessor__mdt settings,
		List<AsyncAction__c> actions,
		Exception failure
	) {
		String processorName = settings.DeveloperName;
		List<AsyncActionPlugin> plugins = getEnabledPlugins(processorName, settings);

		PluginContext context = new PluginContext(settings, actions);
		context.setException(failure);

		for (AsyncActionPlugin plugin : plugins) {
			try {
				plugin.onFailure(context);
			} catch (Exception e) {
				System.debug('Plugin error in onFailure: ' + e.getMessage());
			}
		}
	}

	private static List<AsyncActionPlugin> getEnabledPlugins(String processorName, AsyncActionProcessor__mdt settings) {
		List<AsyncActionPlugin> enabledPlugins = new List<AsyncActionPlugin>();
		List<AsyncActionPlugin> allPlugins = pluginRegistry.get(processorName);

		if (allPlugins != null) {
			for (AsyncActionPlugin plugin : allPlugins) {
				if (plugin.isEnabled(settings)) {
					enabledPlugins.add(plugin);
				}
			}
		}

		return enabledPlugins;
	}

	private static void initializePlugins() {
		// Register global plugins
		registerGlobalPlugin(new AuditPlugin());
		registerGlobalPlugin(new MetricsPlugin());
		registerGlobalPlugin(new RateLimitPlugin());

		// Load processor-specific plugins from metadata
		loadProcessorPlugins();
	}

	private static void registerGlobalPlugin(AsyncActionPlugin plugin) {
		// Register for all processors
		List<AsyncActionProcessor__mdt> allProcessors = [SELECT DeveloperName FROM AsyncActionProcessor__mdt];

		for (AsyncActionProcessor__mdt processor : allProcessors) {
			registerPlugin(processor.DeveloperName, plugin);
		}
	}

	private static void loadProcessorPlugins() {
		List<ProcessorPlugin__mdt> pluginConfigs = [
			SELECT ProcessorName__c, PluginClass__c, Enabled__c
			FROM ProcessorPlugin__mdt
			WHERE Enabled__c = TRUE
		];

		for (ProcessorPlugin__mdt config : pluginConfigs) {
			try {
				Type pluginType = Type.forName(config.PluginClass__c);
				AsyncActionPlugin plugin = (AsyncActionPlugin) pluginType.newInstance();
				registerPlugin(config.ProcessorName__c, plugin);
			} catch (Exception e) {
				System.debug('Failed to load plugin: ' + config.PluginClass__c + ' - ' + e.getMessage());
			}
		}
	}
}
```

## Integration with Core Framework

### Enhanced Processor Wrapper

```apex
global class PluginAwareProcessor implements AsyncActions.Processor {
	private AsyncActions.Processor delegateProcessor;

	public PluginAwareProcessor(AsyncActions.Processor processor) {
		this.delegateProcessor = processor;
	}

	public void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
		try {
			// Execute before-process plugins
			PluginManager.executeBeforeProcess(settings, actions);

			// Execute main processing logic
			delegateProcessor.process(settings, actions);

			// Execute after-process plugins
			PluginManager.executeAfterProcess(settings, actions);
		} catch (Exception e) {
			// Execute failure plugins
			PluginManager.executeOnFailure(settings, actions, e);

			// Re-throw for standard error handling
			throw e;
		}
	}
}
```

## Advanced Plugin Patterns

### Conditional Plugins

Execute plugins based on dynamic conditions:

```apex
global class ConditionalPlugin implements AsyncActionPlugin {
	private AsyncActionPlugin conditionalPlugin;
	private String conditionField;
	private String conditionValue;

	public ConditionalPlugin(AsyncActionPlugin plugin, String field, String value) {
		this.conditionalPlugin = plugin;
		this.conditionField = field;
		this.conditionValue = value;
	}

	public void beforeProcess(PluginContext context) {
		if (shouldExecute(context)) {
			conditionalPlugin.beforeProcess(context);
		}
	}

	public void afterProcess(PluginContext context) {
		if (shouldExecute(context)) {
			conditionalPlugin.afterProcess(context);
		}
	}

	public void onFailure(PluginContext context) {
		if (shouldExecute(context)) {
			conditionalPlugin.onFailure(context);
		}
	}

	public Boolean isEnabled(AsyncActionProcessor__mdt settings) {
		return conditionalPlugin.isEnabled(settings);
	}

	private Boolean shouldExecute(PluginContext context) {
		String settingsValue = (String) context.settings.get(conditionField);
		return settingsValue == conditionValue;
	}
}
```

### Composite Plugin

Chain multiple plugins together:

```apex
global class CompositePlugin implements AsyncActionPlugin {
	private List<AsyncActionPlugin> plugins;

	public CompositePlugin(List<AsyncActionPlugin> plugins) {
		this.plugins = plugins;
	}

	public void beforeProcess(PluginContext context) {
		for (AsyncActionPlugin plugin : plugins) {
			if (plugin.isEnabled(context.settings)) {
				plugin.beforeProcess(context);
			}
		}
	}

	public void afterProcess(PluginContext context) {
		for (AsyncActionPlugin plugin : plugins) {
			if (plugin.isEnabled(context.settings)) {
				plugin.afterProcess(context);
			}
		}
	}

	public void onFailure(PluginContext context) {
		for (AsyncActionPlugin plugin : plugins) {
			if (plugin.isEnabled(context.settings)) {
				plugin.onFailure(context);
			}
		}
	}

	public Boolean isEnabled(AsyncActionProcessor__mdt settings) {
		return true; // Let individual plugins decide
	}
}
```

## External Integration Plugins

### Webhook Plugin

Send processing events to external systems:

```apex
global class WebhookPlugin implements AsyncActionPlugin {
	public void beforeProcess(PluginContext context) {
		sendWebhook('beforeProcess', context);
	}

	public void afterProcess(PluginContext context) {
		sendWebhook('afterProcess', context);
	}

	public void onFailure(PluginContext context) {
		sendWebhook('onFailure', context);
	}

	public Boolean isEnabled(AsyncActionProcessor__mdt settings) {
		return !String.isEmpty(settings.WebhookUrl__c);
	}

	@future(callout=true)
	private static void sendWebhook(String event, PluginContext context) {
		String webhookUrl = context.settings.WebhookUrl__c;
		if (String.isEmpty(webhookUrl))
			return;

		Map<String, Object> payload = new Map<String, Object>{
			'event' => event,
			'processor' => context.settings.DeveloperName,
			'actionCount' => context.actions.size(),
			'timestamp' => DateTime.now().getTime()
		};

		HttpRequest req = new HttpRequest();
		req.setEndpoint(webhookUrl);
		req.setMethod('POST');
		req.setHeader('Content-Type', 'application/json');
		req.setBody(JSON.serialize(payload));

		Http http = new Http();
		HttpResponse res = http.send(req);
	}
}
```

## Testing Plugin Framework

### Plugin Testing

```apex
@isTest
static void testAuditPlugin() {
    AsyncActionProcessor__mdt settings = createTestSettings();
    settings.EnableAudit__c = true;

    List<AsyncAction__c> actions = createTestActions(5);
    PluginContext context = new PluginContext(settings, actions);

    Test.startTest();

    AuditPlugin plugin = new AuditPlugin();
    plugin.beforeProcess(context);
    plugin.afterProcess(context);

    Test.stopTest();

    List<AsyncActionAudit__c> audits = [
        SELECT Phase__c, Status__c FROM AsyncActionAudit__c
    ];

    System.assertEquals(1, audits.size());
    System.assertEquals('Completed', audits[0].Status__c);
}
```

## Best Practices

### Plugin Development

1. **Keep Plugins Lightweight** - Avoid complex logic that could slow processing
2. **Handle Exceptions Gracefully** - Don't let plugin failures break main processing
3. **Use Async Operations** - Offload heavy work to future methods
4. **Design for Reusability** - Make plugins configurable and reusable

### Performance Considerations

1. **Selective Enablement** - Only enable plugins where needed
2. **Efficient Queries** - Minimize SOQL in plugin code
3. **Bulk Operations** - Design plugins for bulk processing
4. **Governor Limits** - Consider plugin impact on limits

## See Also

-   [AsyncActions.Processor Interface](./AsyncActions.Processor-Interface) - Core processor contract
-   [Best Practices](./Best-Practices) - Development best practices
-   [Creating Your First Processor](./Creating-Your-First-Processor) - Basic processor creation
