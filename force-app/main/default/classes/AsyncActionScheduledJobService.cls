global abstract class AsyncActionScheduledJobService {
    @TestVisible
    static Map<String, AsyncActionScheduledJob__mdt> settings;

    global static AsyncActionScheduledJob__mdt get(String developerName) {
        settings = (settings != null) ? settings : AsyncActionScheduledJob__mdt.getAll();
        return settings?.get(developerName);
    }
}