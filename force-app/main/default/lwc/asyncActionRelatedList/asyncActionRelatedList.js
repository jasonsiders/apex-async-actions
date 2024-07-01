import { LightningElement, api, wire } from "lwc";
import { EnclosingTabId, IsConsoleNavigation, openSubtab } from "lightning/platformWorkspaceApi";
import { NavigationMixin } from "lightning/navigation";
import { refreshApex } from "@salesforce/apex";
import { registerRefreshContainer } from "lightning/refresh";
import getActions from "@salesforce/apex/AsyncActionRelatedListController.getActions";
import hasAccess from "@salesforce/apex/AsyncActionRelatedListController.hasAccess";
import ASYNC_ACTION_OBJECT from "@salesforce/schema/AsyncAction__c";
import CREATED_DATE_FIELD from "@salesforce/schema/AsyncAction__c.CreatedDate";
import ERROR_FIELD from "@salesforce/schema/AsyncAction__c.Error__c";
import ID_FIELD from "@salesforce/schema/AsyncAction__c.Id";
import NAME_FIELD from "@salesforce/schema/AsyncAction__c.Name";
import PROCESSOR_FIELD from "@salesforce/schema/AsyncAction__c.ProcessorClass__c";
import RETRIES_FIELD from "@salesforce/schema/AsyncAction__c.Retries__c";
import SCHEDULED_FIELD from "@salesforce/schema/AsyncAction__c.Scheduled__c";
import STATUS_FIELD from "@salesforce/schema/AsyncAction__c.Status__c";
const DEFAULT_TITLE = "Async Actions";
const MAX_ROWS = 6;
const URL_FIELD = "ActionUrl";
const VIEW_ALL_COMPONENT_NAME = "c:asyncActionRelatedPage";
const COLUMNS = [
	{
		fieldName: URL_FIELD,
		hideDefaultActions: true,
		includeInRelatedList: true,
		label: "Async Action",
		type: "url",
		typeAttributes: {
			label: { fieldName: NAME_FIELD?.fieldApiName }
		}
	},
	{
		fieldName: PROCESSOR_FIELD?.fieldApiName,
		hideDefaultActions: true,
		includeInRelatedList: true,
		label: "Processor Class"
	},
	{
		fieldName: STATUS_FIELD?.fieldApiName,
		hideDefaultActions: true,
		includeInRelatedList: true,
		label: "Status"
	},
	{
		fieldName: ERROR_FIELD?.fieldApiName,
		hideDefaultActions: true,
		includeInRelatedList: false,
		label: "Error"
	},
	{
		fieldName: RETRIES_FIELD?.fieldApiName,
		hideDefaultActions: true,
		includeInRelatedList: false,
		label: "Retries",
		type: "number"
	},
	{
		fieldName: SCHEDULED_FIELD?.fieldApiName,
		hideDefaultActions: true,
		includeInRelatedList: true,
		isDefaultSort: false,
		label: "Scheduled",
		type: "date",
		typeAttributes: {
			day: "2-digit",
			hour: "2-digit",
			minute: "2-digit",
			month: "2-digit",
			year: "2-digit"
		}
	},
	{
		fieldName: CREATED_DATE_FIELD?.fieldApiName,
		hideDefaultActions: true,
		includeInRelatedList: false,
		label: "Created Date",
		type: "date",
		typeAttributes: {
			day: "2-digit",
			hour: "2-digit",
			minute: "2-digit",
			month: "2-digit",
			year: "2-digit"
		}
	}
];

export default class AsyncActionRelatedList extends NavigationMixin(LightningElement) {
	@api recordId;
	_actions = [];
	cachedQueryResponse;
	hasMore = false;
	_isLoading = true;
	refreshContainerId;
	_title;

	get actions() {
		return this._actions || [];
	}

	set actions(value) {
		// Use this property to store records/rows from the parent component to display in the list.
		// Note: Setter used to enforce the maximum # of rows, defined by the MAX_ROWS property.
		const numRows = value?.length || 0;
		this.hasMore = numRows > MAX_ROWS;
		this._actions = value?.slice(0, MAX_ROWS);
	}

	get actionObjectName() {
		return ASYNC_ACTION_OBJECT?.objectApiName;
	}

	get columns() {
		return COLUMNS?.filter((column) => column?.includeInRelatedList);
	}

	get hasActions() {
		return !!this.actions?.length;
	}

	get hasViewAccess() {
		return this.accessResponse?.data;
	}

	get header() {
		// Should display the number of records, unless it exceeds the row limit.
		// then indicate that the number exceeds the maximum display size
		// The user should click on the "View All" button in this case
		const numRows = this.actions?.length || 0;
		const count = this.hasMore && numRows > 0 ? `${numRows}+` : numRows;
		return `${this.title} (${count})`;
	}

	get idField() {
		return ID_FIELD?.fieldApiName;
	}

	get isLoading() {
		return this._isLoading || false;
	}

	set isLoading(value) {
		// Used to manipulate the related list's spinner from parent components.
		// Note: Setter used to implement a short timeout on disable,
		// to make it more obvious to users when a refresh occurs
		const waitMs = value ? 0 : 50;
		setTimeout(() => {
			this._isLoading = value;
		}, waitMs);
	}

	get title() {
		return this._title || DEFAULT_TITLE;
	}

	@api set title(value) {
		this._title = value;
	}

	get viewAllComponent() {
		// Defines the component to be opened when "View All" is clicked
		// Note: We're not sure why, but for some reason, schema imports in c:asyncActionRelatedPage
		// NEVER include the namespace of the object/field - even in namespaced environments.
		// Get around this by passing the (correctly namespaced) values to the component (see below).
		return {
			componentDef: VIEW_ALL_COMPONENT_NAME,
			attributes: {
				columns: COLUMNS,
				objectApiName: this.actionObjectName,
				title: this.title,
				recordId: this.recordId
			}
		};
	}

	get viewAllUrl() {
		return `/one/one.app#${btoa(JSON.stringify(this.viewAllComponent))}`;
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

	@wire(hasAccess)
	accessResponse;

	@wire(EnclosingTabId)
	currentTabId;

	@wire(IsConsoleNavigation)
	isConsole;

	@wire(getActions, { recordId: "$recordId" })
	queryResponse(response) {
		this.cachedQueryResponse = response;
		if (response?.data) {
			this.mapActions(response?.data)?.then((results) => {
				this.actions = results;
				this.isLoading = false;
			});
		}
	}

	async handleRefresh() {
		this.isLoading = true;
		await refreshApex(this.cachedQueryResponse);
		this.isLoading = false;
	}

	async handleViewAll(event) {
		// Navigate to the supplied viewAllComponent.
		// The navigation method depends on if the current app is a console
		if (this.isConsole) {
			this.viewAllInConsoleApp();
		} else {
			this.viewAllInStandardApp();
		}
	}

	async mapActions(data) {
		// Add the "ActionUrl" field - hyperlink which is used in the Name column
		const actions = data?.map((row) => {
			const ActionUrl = `/${row?.Id}`;
			return { ...row, ActionUrl };
		});
		return actions;
	}

	async viewAllInConsoleApp() {
		// When being used in the context of a Lightning Console,
		// use the Workspace API to open the view all component in a new subtab
		await openSubtab(this.currentTabId, {
			focus: true,
			icon: "custom:custom25",
			iconAlt: this.title,
			label: this.title,
			url: this.viewAllUrl
		});
	}

	async viewAllInStandardApp() {
		// When not used in the context of Lightning Console,
		// use the NavigationMixin to open the view all component in the same window.
		this[NavigationMixin.Navigate]({
			type: "standard__webPage",
			attributes: {
				url: this.viewAllUrl
			}
		});
	}
}
