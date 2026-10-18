/**
 * @description Provides framework-wide logging by delegating to a configurable adapter.
 * Defaults to System.debug; subscribers supply a custom adapter (or a System.Callable logger, like Nebula Logger's CallableLogger)
 * via the LoggerPlugin AsyncActionParameter__mdt so log output can be routed to any platform without changing call sites.
 */
// Global modifier and debug statements are required for subscriber extensibility; empty save() block is an intentional no-op
@SuppressWarnings('PMD.AvoidDebugStatements,PMD.AvoidGlobalModifier,PMD.EmptyStatementBlock')
global abstract class AsyncActionLogger {
	/** @description Shared fallback so DefaultLogger is only constructed once regardless of which code path triggers it **/
	private static final AsyncActionLogger.Adapter DEFAULT_LOGGER = new AsyncActionLogger.DefaultLogger();

	/** @description Cached once at class load to avoid repeated metadata queries per transaction **/
	@TestVisible
	private static final AsyncActionLogger.Adapter INSTANCE = AsyncActionLogger.getInstance() ?? DEFAULT_LOGGER;

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
	 * @description Reads the LoggerPlugin parameter once so initialization cost is paid only once per transaction
	 * @return Configured adapter, or DefaultLogger when none is specified or the specified class fails to load
	 */
	private static AsyncActionLogger.Adapter getInstance() {
		String adapterName;
		try {
			adapterName = AsyncActionParameterService.getParameter('LoggerPlugin');
			AsyncActionLogger.Adapter adapter = String.isNotBlank(adapterName)
				? AsyncActionLogger.initAdapter(adapterName)
				: DEFAULT_LOGGER;
			return adapter ?? DEFAULT_LOGGER;
		} catch (Exception error) {
			String msg = adapterName + ' is not an instance of AsyncActionLogger.Adapter or System.Callable';
			System.debug(System.LoggingLevel.WARN, msg);
			return DEFAULT_LOGGER;
		}
	}

	/**
	 * @description Instantiates the named plugin; System.Callable plugins (ex., Nebula Logger's CallableLogger) are wrapped
	 * so subscribers can use them without a compile-time dependency or a custom adapter
	 * @param adapterName Fully qualified name of a class that implements AsyncActionLogger.Adapter or System.Callable
	 * @return The plugin as an adapter, or null if the class does not exist
	 */
	private static AsyncActionLogger.Adapter initAdapter(String adapterName) {
		Object plugin = Type.forName(adapterName)?.newInstance();
		return (plugin instanceof System.Callable && !(plugin instanceof AsyncActionLogger.Adapter))
			? new AsyncActionLogger.CallableAdapter((System.Callable) plugin)
			: (AsyncActionLogger.Adapter) plugin;
	}

	// **** INNER **** //

	/** @description Contract custom adapters must satisfy; implement and register the class name via the LoggerPlugin AsyncActionParameter__mdt **/
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

	/** @description Bundled fallback that writes to System.debug; active when no LoggerPlugin parameter is configured **/
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

	/** @description Translates Adapter calls into Nebula Logger's CallableLogger actions; active when LoggerPlugin names a System.Callable **/
	@TestVisible
	private class CallableAdapter implements AsyncActionLogger.Adapter {
		/** @description Typed as System.Callable so the package compiles without Nebula Logger installed **/
		private System.Callable logger;

		/**
		 * @description Private so it is only constructed when the LoggerPlugin parameter names a System.Callable
		 * @param logger The callable logger to send entries to
		 */
		private CallableAdapter(System.Callable logger) {
			this.logger = logger;
		}

		/**
		 * @description Adds a log entry via the newEntry action; exceptions are also passed whole so their stack trace is kept
		 * @param level The logging level for the message
		 * @param logMessage The message or object to log
		 */
		public void log(System.LoggingLevel level, Object logMessage) {
			Map<String, Object> args = new Map<String, Object>{
				'loggingLevel' => level,
				'message' => String.valueOf(logMessage)
			};
			if (logMessage instanceof Exception) {
				args?.put('exception', logMessage);
			}
			this.logger?.call('newEntry', args);
		}

		/** @description Saves buffered entries via the saveLog action, using the logger's default save method **/
		public void save() {
			this.logger?.call('saveLog', null);
		}
	}
}
