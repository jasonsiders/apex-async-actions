public class AsyncActionStartHandler extends apxsp.TriggerHandler {
    public override void afterInsert() {
        // Regardless of the number of of events, launch all jobs only once
        AsyncActionLauncher.launchAll();
    }
    
    public override Type getType() {
        return AsyncActionStartHandler.class;
    }
}