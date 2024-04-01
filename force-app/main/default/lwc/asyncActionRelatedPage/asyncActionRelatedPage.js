import { LightningElement, api, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { getObjectInfo } from "lightning/uiObjectInfoApi";
import { refreshApex } from "@salesforce/apex";
import { registerRefreshContainer } from "lightning/refresh";
import getActions from "@salesforce/apex/AsyncActionRelatedListController.getActions";
import ID_FIELD from "@salesforce/schema/AsyncAction__c.Id";
const Defaults = {
	DISPLAY_SIZE: 50,
	LOAD_MORE_INCREMENT: 20,
	SORT_DIRECTION: "desc"
};
const NoDataIllustration = {
	DETAIL: "There's nothing in your list yet. Try adding a new record.",
	HEADER: "Nothing to see here",
	SRC: "/img/chatter/Desert.svg"
};
const SortLabels = { 
	asc: "Ascending", 
	desc: "Descending" 
};

export default class AsyncActionRelatedPage extends NavigationMixin(LightningElement) {
	@api objectApiName;
	@api recordId;
	allActions = [];
	cachedQueryResponse;
	_columns;
	displaySize = Defaults.DISPLAY_SIZE;
	enableInfiniteLoading = true;
	_isLoading = true;
	refreshContainerId;
	rows = [];
	sortByField;
	sortByLabel;
	sortDirection = Defaults.SORT_DIRECTION;
	table;

	@api set columns(values) {
		// All columns on the full-page version of this component should be sortable
		let columns = JSON.parse(JSON.stringify(values));
		columns?.forEach((column) => {
			column.sortable = true;
			if (column?.isDefaultSort) {
				this.sortByField = column?.fieldName;
				this.sortByLabel = column?.label;
			}
		});
		this._columns = columns;
	}

	get columns() {
		return this._columns;
	}

	get countDetail() {
		// Returns a formatted blurb about the number of visible/total records
		const numRows = this.allActions?.length || 0;
		const count = this.showingAll ? numRows : `${this.displaySize}+`;
		return `${count} Items`;
	}

	get hasRows() {
		return !!this.rows?.length;
	}

	get idField() {
		return ID_FIELD?.fieldApiName;
	}

	get isLoading() {
		return this._isLoading;
	}

	set isLoading(value) {
		// Used to manipulate the related list's spinner from parent components.
		// Note: Setter used to implement a short timeout on disable,
		// to make it more obvious to users when a refresh occurs
		const waitMs = value ? 0 : 50;
		setTimeout(() => {
			this._isLoading = value;
			if (this.table) {
				this.table.isLoading = value;
			}
		}, waitMs);
	}

	get missingDataDetail() {
		return NoDataIllustration.DETAIL;
	}

	get missingDataHeader() {
		return NoDataIllustration.HEADER;
	}

	get missingDataImage() {
		// Returns the path to a stock illustration used to indicate no data
		return NoDataIllustration.SRC;
	}

	get navBackLabel() {
		return this.recordId ? "< Back" : "";
	}

	get showingAll() {
		// Returns true if all records are being displayed
		return this.rows?.length === this.allActions?.length;
	}

	get sortDetail() {
		// Returns a formatted blurb about the current sort by field & direction
		const prefix = "Sorted By";
		let parts = [prefix, this.sortByLabel, this.sortDirectionDetail];
		parts = parts?.filter((part) => !!part);
		return this.sortByLabel ? parts?.join(" ") : undefined;
	}

	get sortDirectionDetail() {
		// Returns a formatted blurb about the current sort direction
		const sortDirection = SortLabels[this.sortDirection];
		return sortDirection ? `(${sortDirection})` : "";
	}

	get sortingAlgorithm() {
		// Defines a sorting function used to re-sort columns
		const sortByField = this.sortByField; 
		const reverse = (this.sortDirection === "asc") ? 1 : -1;
        const key = function(x) {
			return x[sortByField];
		};
        return function(a, b) {
            a = key(a);
            b = key(b);
            return reverse * ((a > b) - (b > a));
        };
	}

	get subtitle() {
		// Returns a blurb w/details about the quantity of records returned and their sort order
		let parts = [this.countDetail, this.sortDetail];
		parts = parts?.filter((part) => !!part);
		return parts?.join(" • ");
	}

	get tableStyle() {
		// Setting a fixed height is necessary for infinite loading to function properly
		return `height: ${window?.innerHeight * 0.9}px`;
	}

	get title() {
		return this.objectInfoResponse?.data?.labelPlural || "";
	}

	connectedCallback() {
		try {
			// Note: If LWS is not enabled, this will thrown an error. This can/should be enabled in Session Settings
			// if using Lightning Locker, will not be able to handle incoming refreshes.
			this.refreshContainerId = registerRefreshContainer(this, this.handleRefresh);
		} catch (error) {
			console.error(`c:asyncActionRelatedPage: ${error}`);
		}
	}

	@wire(getObjectInfo, { objectApiName: "$objectApiName" })
	objectInfoResponse;

	@wire(getActions, { recordId: "$recordId" })
	queryResponse(response) {
		this.cachedQueryResponse = response;
		if (response?.data) {
			this.mapActions(response?.data)?.then(() => this.renderData());
		} else if (response?.error) {
			console.error(`c:asyncActionRelatedPage: ${JSON.stringify(response?.error)}`);
		}
	}

	async handleLoadMore(event) {
		// Handle the onloadmore event from the lightning-datatable
		event?.preventDefault();
		this.table = event?.target;
		if (this.showingAll === true) {
			// No more data to load - disable
			this.enableInfiniteLoading = false;
		} else {
			// Display additional records; already loaded by the @wire method
			this.isLoading = true;
			const totalRows = this.allActions?.length || 0;
			const newNumRows = this.displaySize + Defaults.LOAD_MORE_INCREMENT;
			this.displaySize = Math.min(newNumRows, totalRows);
			this.renderData();
		}
	}

	async handleNavBack(event) {
		// Returns the user back to the source record
		if (this.recordId) {
			this[NavigationMixin.Navigate]({
				type: "standard__recordPage",
				attributes: {
					recordId: this.recordId,
					actionName: "view"
				}
			});
		}
	}

	async handleRefresh() {
		this.isLoading = true;
		await refreshApex(this.cachedQueryResponse);
		this.isLoading = false;
	}

	async handleSort(event) {
		// Re-sort the actions in the list based on the event details
		this.isLoading = true; 
		const params = event?.detail;
		await this.setSortParams(params);
		this.sortData();
	}

	async mapActions(actions) {
		// Add hyperlink "fields" to the objects returned from the database
		this.allActions = actions?.map((action) => {
			const ActionUrl = `/${action?.Id}`;
			return { ...action, ActionUrl };
		});
	}

	async renderData() {
		// Render the specified number of rows
		this.rows = this.allActions?.slice(0, this.displaySize);
		this.isLoading = false;
	}

	async setSortParams(params) {
		// Expects a lightning-datatable column sort event.detail object
		// Sets the component's current sort parameters based on the incoming parameters
		const sortByColumn = this.columns?.find((column) => column?.fieldName === params?.fieldName);
		this.sortByLabel = sortByColumn?.label;
		this.sortByField = sortByColumn?.fieldName;
		this.sortDirection = params?.sortDirection;
	}

	async sortData() {
		try {
			// Sorts all actions according to the current component's sort parameters
			this.isLoading = true;
			this.allActions = [...this.allActions]?.sort(this.sortingAlgorithm);
			await this.renderData();
		} catch (error) {
			this.isLoading = false;
			console.error(`c:asyncActionRelatedPage: ${error}`);
		}
	}
}