import { LightningElement, api } from 'lwc';
import runAction from "@salesforce/apex/RunAsyncActionNowController.runAction";

export default class RunAsyncActionNow extends LightningElement {
    @api recordId; 

    @api invoke() {
        console.log(`c:RunAsyncActionNow`);
    }
}