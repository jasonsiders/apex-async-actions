global abstract class AsyncActionSettingService {
    static final Integer DEFAULT_INTERVAL = 60; 
    static final String DEFAULT_KEY = 'Default'; 
    @TestVisible
    static AsyncActionSetting__mdt settings;    

    global static AsyncActionSetting__mdt getSettings() {
        settings = (settings != null) ? settings : AsyncActionSetting__mdt.getInstance(DEFAULT_KEY);
        return settings; 
    }

    public static Integer getScheduledInterval() {
        Integer value = AsyncActionSettingService.getSettings()?.ScheduledJobInterval__c?.intValue();
        return (value != null) ? value : DEFAULT_INTERVAL;
    }
}