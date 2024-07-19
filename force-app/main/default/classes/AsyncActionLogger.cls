public abstract class AsyncActionLogger {
    static final AsyncActionLogger.Adapter INSTANCE = AsyncActionLogger.getInstance();
    
    public static AsyncActionLogger.Adapter init() {
        // Returns the current logger instance for this transaction
        return INSTANCE ?? new DefaultLogger();
    } 

    static AsyncActionLogger.Adapter getInstance() {
        // Initialize a log adapter object based on the provided value in custom metadata
        // If no metadata records, or if an invalid adapter is defined, will use the DefaultLogger instead
        AsyncActionGlobalSetting__mdt settings = AsyncActionGlobalSettingService.getSettings();
        String adapterName = settings?.LoggerAdapter__c;
        try {
            return (AsyncActionLogger.Adapter) Type.forName(adapterName)?.newInstance();
        } catch (Exception error) {
            String msg = adapterName + ' is not an instance of AsyncActionLogger.Adapter\nOriginal Error: ' + error;
            System.debug(System.LoggingLevel.WARN, msg);
            return null;
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
            String loggedFromBlurb = (loggedFromClass != null) ? '\nLogged From: ' + loggedFromClass : '';
            String relatedToBlurb = (relatedRecordId != null) ? '\nRelated To: ' + relatedRecordId : '';
            String log = (logMessage + loggedFromBlurb + relatedToBlurb);
            System.debug(level, log);
        }
    
        public void save(Boolean publishImmediately) {
            // Many custom logging tools require a method like this, to commit logs to the database.
            // However, traditional salesforce debug logs do not require this, so this method will no-op.
        }
    }
}