global abstract class AsyncActionScheduledJobService {
    @TestVisible
    static Map<String, AsyncActionScheduledJob__mdt> settings;

    global static List<AsyncActionScheduledJob__mdt> getAll() {
        AsyncActionScheduledJobService.retrieveSettings();
        return AsyncActionScheduledJobService.settings?.values();
    }
    
    global static AsyncActionScheduledJob__mdt get(String developerName) {
        AsyncActionScheduledJobService.retrieveSettings();
        return settings?.get(developerName);
    }

    static void retrieveSettings() {
        settings = (settings != null) ? settings : AsyncActionScheduledJob__mdt.getAll();
    }
}