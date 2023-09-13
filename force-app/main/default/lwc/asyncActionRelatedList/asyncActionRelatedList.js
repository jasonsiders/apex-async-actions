import { LightningElement, api, wire } from "lwc";
import getColumns from "./columns";
import { refreshApex } from "@salesforce/apex";
import { registerRefreshContainer } from "lightning/refresh";
import ASYNC_ACTION_OBJECT from "@salesforce/schema/AsyncAction__c";
import getActions from "@salesforce/apex/AsyncActionRelatedListController.getActions";
import hasAccess from "@salesforce/apex/AsyncActionRelatedListController.hasAccess";
const VIEW_ALL_COMPONENT_NAME = "asyncActionRelatedPage";

export default class AsyncActionRelatedList extends LightningElement {
	@api recordId;
	allColumns = getColumns();
	cachedAccessResponse;
	cachedQueryResponse;
	hasViewAccess = false;
	isLoading = true;
	actions = [];
	actionObject = ASYNC_ACTION_OBJECT;

	get relatedListColumns() {
		// Display a subset of all columns for the related list page
		// The related list page will contain the full list of columns
		const subset = this.allColumns?.filter((column) => {
			return column.includeInRelatedList === true;
		});
		return subset;
	}

	get viewAllComponent() {
		return {
			componentDef: this.viewAllComponentName,
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

	get viewAllComponentName() {
		const namespace = this.getNamespace() || "c";
		return `${namespace}:${VIEW_ALL_COMPONENT_NAME}`;
	}

	connectedCallback() {
		this.refreshContainerId = registerRefreshContainer(this, this.handleRefresh);
	}

	@wire(hasAccess)
	checkAccess(response) {
		this.cachedAccessResponse = response;
		if (response?.data) {
			this.hasViewAccess = response?.data;
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

    getNamespace() {
		const BASE_API_NAME = "AsyncAction__c"; 
		return ASYNC_ACTION_OBJECT?.objectApiName?.replace(BASE_API_NAME, "")?.replace("__", "");
	}

	handleRefresh() {
		this.isLoading = true;
		refreshApex(this.cachedAccessResponse);
		refreshApex(this.cachedQueryResponse).then(() => {
			this.isLoading = false;
		});
	}
}
