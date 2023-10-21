import { LightningElement, api } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import runAction from "@salesforce/apex/RunAsyncActionNowController.runAction";

export default class RunAsyncActionNow extends LightningElement {
    @api recordId; 

    @api invoke() {
        runAction({ recordId: this.recordId })?.then(() => {
            this.dispatchEvent(new ShowToastEvent({
                title: "Success!",
                message: "Running your action now. Check back in a few moments.",
                variant: "success"
            }));
        }).catch((error) => {
            this.dispatchEvent(new ShowToastEvent({
                title: "An error occurred:",
                message: error?.body?.message,
                variant: "error"
            }));
        });
    }
}