public abstract class AsyncActionLogger {
    public static AsyncActionLogger.Adapter init() {
        // Initialize a log adapter object based ont he provided value in custom metadata
        // If no metadata records, or if an invalid adapter is defined, will use the DefaultLogger instead
        AsyncActionGlobalSetting__mdt settings = AsyncActionGlobalSettingService.getSettings();
        String adapterName = settings?.LoggerAdapter__c;
        try {
            AsyncActionLogger.Adapter adapter = (AsyncActionLogger.Adapter) Type.forName(adapterName)?.newInstance();
            return adapter ?? new DefaultLogger();
        } catch (Exception error) {
            String msg = adapterName + ' is not a valid instance of AsyncActionLogger.Adapter\nOriginal Error: ' + error;
            AsyncActionLogger.Adapter defaultLogger = new DefaultLogger();
            defaultLogger?.log(System.LoggingLevel.WARN, AsyncActionLogger.class, null, msg); 
            return defaultLogger;
        }
    } 

    // **** INNER **** //
    public interface Adapter {
        void log(System.LoggingLevel level, Type loggedFromClass, Id relatedRecordId, Object logMessage);
        void save(Boolean publishImmediate);
    }

    public class DefaultLogger implements AsyncActionLogger.Adapter {
        // The default log implementation will post logs to traditional Salesforce debug logs

        private DefaultLogger() {
            // Conventionally, adapters should not be constructed manually. 
            // Callers should use the static init() method to retrieve the correct adapter instead.
        }

        public void log(System.LoggingLevel level, Type loggedFromClass, Id relatedRecordId, Object logMessage) {
            // Print to traditional salesforce debug logs
            String log = 'Logged From: ' + loggedFromClass + '\n' 
                + 'Related To: ' + relatedRecordId + '\n'
                + 'Log Message: ' + logMessage;
            System.debug(level, log);
        }
    
        public void save(Boolean publishImmediately) {
            // Many custom logging tools require a method like this, to commit logs to the database.
            // However, traditional salesforce debug logs do not require this, so this method will no-op.
        }
    }
}