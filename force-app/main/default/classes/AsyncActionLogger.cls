/**
 * @description Abstract logging class responsible for logging details about the AsyncActionFramework.
 * By default, it uses standard System.debug logs.
 * Subscribers can write their own logging plugins via the AsyncActionLogger.Adapter interface
 * and register it in the AsyncActionGlobalSetting__mdt.LoggerPlugin__c field.
 * The framework stores the current logging instance in a singleton,
 * which is accessed by the static log and save methods by the application.
 */
@SuppressWarnings('PMD.AvoidDebugStatements,PMD.AvoidGlobalModifier,PMD.EmptyStatementBlock')
global abstract class AsyncActionLogger {
	/**
	 * @description Test visible singleton instance of the configured logging adapter
	 */
	@TestVisible
	private static final AsyncActionLogger.Adapter INSTANCE = AsyncActionLogger.getInstance();

	/**
	 * @description Logs a message at the specified logging level using the configured adapter.
	 * @param level The logging level for the message
	 * @param logMessage The message or object to log
	 */
	global static void log(System.LoggingLevel level, Object logMessage) {
		// Call the singleton instance's log method
		INSTANCE?.log(level, logMessage);
	}

	/**
	 * @description Saves/commits any pending log entries using the configured adapter.
	 */
	global static void save() {
		// Call the singleton instance's save method
		INSTANCE?.save();
	}

	/**
	 * @description Gets the configured logging adapter instance based on global settings
	 * @return The configured logging adapter, or DefaultLogger if none specified or invalid
	 */
	private static AsyncActionLogger.Adapter getInstance() {
		// Initialize a log adapter object based on the provided value in custom metadata
		// If no metadata records, or if an invalid adapter is defined, will use the DefaultLogger instead
		String adapterName;
		try {
			AsyncActionGlobalSetting__mdt settings = AsyncActionGlobalSettingService.getSettings();
			adapterName = settings?.LoggerPlugin__c;
			AsyncActionLogger.Adapter adapter = (AsyncActionLogger.Adapter) Type.forName(adapterName)?.newInstance();
			return adapter ?? new AsyncActionLogger.DefaultLogger();
		} catch (Exception error) {
			System.debug(System.LoggingLevel.WARN, adapterName + ' is not a instance of AsyncActionLogger.Adapter');
			return new AsyncActionLogger.DefaultLogger();
		}
	}

	// **** INNER **** //
	/**
	 * @description Interface for custom logging adapters.
	 * Implement this interface and specify the fully qualified API name of your class
	 * in AsyncActionGlobalSetting__mdt.LoggerPlugin__c to use custom logging.
	 */
	global interface Adapter {
		/**
		 * @description Logs a message at the specified level.
		 * @param level The logging level for the message
		 * @param logMessage The message or object to log
		 */
		void log(System.LoggingLevel level, Object logMessage);
		/**
		 * @description Saves/commits any pending log entries.
		 */
		void save();
	}

	/**
	 * @description Test visible default logging implementation that uses System.debug
	 */
	@TestVisible
	private class DefaultLogger implements AsyncActionLogger.Adapter {
		/**
		 * @description Private constructor for DefaultLogger
		 * The default log implementation will post logs to traditional Salesforce debug logs
		 */
		private DefaultLogger() {
			// This adapter should not be constructed manually,
			// or otherwise accessed directly by external consumers
		}

		/**
		 * @description Logs a message using System.debug
		 * @param level The logging level for the message
		 * @param logMessage The message or object to log
		 */
		public void log(System.LoggingLevel level, Object logMessage) {
			// Print to traditional salesforce debug logs
			System.debug(level, logMessage);
		}

		/**
		 * @description No-op save method for System.debug logging
		 */
		public void save() {
			// Many custom logging tools require a method like this, to commit logs to the database.
			// However, traditional salesforce debug logs do not require this, so this method will no-op.
		}
	}
}
