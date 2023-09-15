import { LightningElement, api, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import getActions from "@salesforce/apex/AsyncActionRelatedListController.getActions";

export default class AsyncActionRelatedPage extends NavigationMixin(LightningElement) {
	@api columns;
	@api objectApiName;
	@api recordId;
	actions;

	@wire(getActions, { recordId: "$recordId" })
	result({ data, error }) {
		if (data) {
			this.actions = data.map((row) => {
				const ActionUrl = `/${row?.Id}`;
				const CreatedByName = row?.CreatedBy?.Name;
				const CreatedByUrl = `/${row?.CreatedById}`;
				return { ...row, ActionUrl, CreatedByName, CreatedByUrl };
			});
		} else if (error) {
			console.error(`apxsp:asyncActionRelatedPage: ${JSON.stringify(error)}`);
		}
	}
}
