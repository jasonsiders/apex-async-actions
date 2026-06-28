/**
 * @description Provides framework-wide logging by delegating to a configurable adapter.
 * Defaults to System.debug; subscribers supply a custom adapter via AsyncActionGlobalSetting__mdt.LoggerPlugin__c
 * so log output can be routed to any platform without changing call sites.
 */
// Global modifier and debug statements are required for subscriber extensibility; empty save() block is an intentional no-op
@SuppressWarnings('PMD.AvoidDebugStatements,PMD.AvoidGlobalModifier,PMD.EmptyStatementBlock')
global abstract class AsyncActionLogger {
	/** @description Cached once at class load to avoid repeated metadata queries per transaction **/
	@TestVisible
	private static final AsyncActionLogger.Adapter INSTANCE = AsyncActionLogger.getInstance() ??
		new AsyncActionLogger.DefaultLogger();

	/**
	 * @description Delegates to the configured adapter so call sites are decoupled from the adapter implementation
	 * @param level The logging level for the message
	 * @param logMessage The message or object to log
	 */
	global static void log(System.LoggingLevel level, Object logMessage) {
		INSTANCE?.log(level, logMessage);
	}

	/** @description Flushes buffered log entries; delegated to the adapter since only custom adapters require an explicit flush **/
	global static void save() {
		INSTANCE?.save();
	}

	// **** PRIVATE **** //

	/**
	 * @description Reads LoggerPlugin__c once so initialization cost is paid only once per transaction
	 * @return Configured adapter, or DefaultLogger when none is specified or the specified class fails to load
	 */
	private static AsyncActionLogger.Adapter getInstance() {
		String adapterName;
		try {
			AsyncActionGlobalSetting__mdt settings = AsyncActionGlobalSettingService.getSettings();
			adapterName = settings?.LoggerPlugin__c;
			AsyncActionLogger.Adapter adapter = String.isBlank(adapterName)
				? new AsyncActionLogger.DefaultLogger()
				: (AsyncActionLogger.Adapter) Type.forName(adapterName)?.newInstance();
			return adapter ?? new AsyncActionLogger.DefaultLogger();
		} catch (Exception error) {
			System.debug(System.LoggingLevel.WARN, adapterName + ' is not a instance of AsyncActionLogger.Adapter');
			return new AsyncActionLogger.DefaultLogger();
		}
	}

	// **** INNER **** //

	/** @description Contract custom adapters must satisfy; implement and register the class name via AsyncActionGlobalSetting__mdt.LoggerPlugin__c **/
	global interface Adapter {
		/**
		 * @description Called on every log statement; implementations must be safe to invoke in any execution context
		 * @param level The logging level for the message
		 * @param logMessage The message or object to log
		 */
		void log(System.LoggingLevel level, Object logMessage);
		/** @description Flushes buffered entries; called after each trigger and job execution **/
		void save();
	}

	/** @description Bundled fallback that writes to System.debug; active when no LoggerPlugin__c is configured **/
	@TestVisible
	private class DefaultLogger implements AsyncActionLogger.Adapter {
		/** @description Private to prevent external construction; access logging via AsyncActionLogger.log and AsyncActionLogger.save **/
		private DefaultLogger() {
		}

		/**
		 * @description Routes the message to System.debug so it appears in standard debug logs
		 * @param level The logging level for the message
		 * @param logMessage The message or object to log
		 */
		public void log(System.LoggingLevel level, Object logMessage) {
			System.debug(level, logMessage);
		}

		/** @description System.debug writes are immediate so no flush step is needed; declared to satisfy the Adapter contract **/
		public void save() {
		}
	}
}
