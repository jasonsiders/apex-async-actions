import { LightningElement, api, wire } from "lwc";
import getColumns from "./columns";
import { refreshApex } from "@salesforce/apex";
import { registerRefreshContainer } from "lightning/refresh";
import ASYNC_ACTION_OBJECT from "@salesforce/schema/AsyncAction__c";
import getActions from "@salesforce/apex/AsyncActionRelatedListController.getActions";
const VIEW_ALL_COMPONENT_NAME = "c:asyncActionRelatedPage";

export default class AsyncActionRelatedList extends LightningElement {
	@api recordId;
	actions = [];
	actionObject = ASYNC_ACTION_OBJECT?.objectApiName;
	allColumns = getColumns();
	cachedQueryResponse;
	isLoading = true;
	refreshContainerId;

	get relatedListColumns() {
		// Display a subset of all columns for the related list page
		// The related list page will contain the full list of columns
		const subset = this.allColumns?.filter((column) => {
			return column?.includeInRelatedList === true;
		});
		return subset;
	}

	get viewAllComponent() {
		return {
			componentDef: VIEW_ALL_COMPONENT_NAME,
			attributes: {
				columns: this.allColumns,
				objectApiName: this.actionObject,
				recordId: this.recordId
			},
			tabInfo: {
				iconName: "custom:custom25",
				title: "Async Actions"
			}
		};
	}

	connectedCallback() {
		try {
			// Note: If LWS is not enabled, this will thrown an error. This can/should be enabled in Session Settings
			// if using Lightning Locker, will not be able to handle incoming refreshes.
			this.refreshContainerId = registerRefreshContainer(this, this.handleRefresh);
		} catch (error) {
			console.error(`c:asyncActionRelatedList: ${error}`);
		}
	}

	@wire(getActions, { recordId: "$recordId" })
	queryActions(response) {
		this.cachedQueryResponse = response;
		if (response?.data) {
			this.mapActions(response?.data)?.then((results) => {
				this.actions = results;
				this.isLoading = false;
			});
		}
	}

	async mapActions(data) {
		const actions = data?.map((row) => {
			const ActionUrl = `/${row?.Id}`;
			return { ...row, ActionUrl };
		});
		return actions;
	}

	handleRefresh() {
		this.isLoading = true;
		refreshApex(this.cachedQueryResponse).then(() => {
			this.isLoading = false;
		});
	}
}
