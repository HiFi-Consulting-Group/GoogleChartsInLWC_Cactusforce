import { LightningElement, track } from "lwc";

import getVFDomain from "@salesforce/apex/GranteeMapController.getVFDomain";
import getGrantYearsData from "@salesforce/apex/GranteeMapController.getGrantYearsData";
import getFocusAreasData from "@salesforce/apex/GranteeMapController.getFocusAreasData";
import getInvestigatorData from "@salesforce/apex/GranteeMapController.getInvestigatorData";
import getGlobalGranteeDetail from "@salesforce/apex/GranteeMapController.getGlobalGranteeDetail";
import getUSGranteeDetail from "@salesforce/apex/GranteeMapController.getUSGranteeDetail";

export default class GranteeHeatmapFilters extends LightningElement {
	vfDomain;
    isLoading = true;
    activeSections = ["GlobalMap", "USMap", "GlobalMapData", "USMapData"];
    activeFilterSections = [];
    availableGrantYears = [];
    selectedGrantYears = [];
    availableFocusAreas = [];
    selectedFocusAreas = [];
    availableInvestigators = [];
    selectedInvestigators = [];

    // Track whether filters have been applied.  Initially the app behaves as if ALL are selected, but displays none
    yearFiltersApplied = false;
    focusFiltersApplied = false;
    investigatorFiltersApplied = false;
    allYears = [];
    allFocusAreas = [];
    allInvestigators = [];

    // Table Sort vars
    globalSortedBy = "AccountName";
    globalSortedDirection = "asc";
    usSortedBy = "AccountName";
    usSortedDirection = "asc";

    // Data table vars
    globalMapOpps = [];
    @track filteredGlobalMapOpps;
    usMapOpps = [];
    @track filteredUsMapOpps;

    globalMapColumns = [
        {
            label: "Opp Name",
            fieldName: "RecordURL",
            sortable: "true",
            type: "url",
            typeAttributes: { label: { fieldName: "Name" }, target: "_blank" }
        },
        { label: "Country", fieldName: "CountryCode", sortable: "true" },
        { label: "Focus Area", fieldName: "Focus_Area__c", sortable: "true" },
        {
            label: "Grant Investigator",
            fieldName: "GrantInvestigator",
            sortable: "true"
        },
        {
            label: "Amount",
            fieldName: "Amount",
            type: "currency",
            sortable: "true"
        },
        {
            label: "Rec Submitted Date",
            fieldName: "Rec_Submitted__c",
            type: "date",
            sortable: "true"
        }
    ];

    usMapColumns = [
        {
            label: "Opp Name",
            fieldName: "RecordURL",
            sortable: "true",
            type: "url",
            typeAttributes: { label: { fieldName: "Name" }, target: "_blank" }
        },
        { label: "State", fieldName: "stateCode", sortable: "true" },
        { label: "Focus Area", fieldName: "Focus_Area__c", sortable: "true" },
        {
            label: "Grant Investigator",
            fieldName: "GrantInvestigator",
            sortable: "true"
        },
        {
            label: "Amount",
            fieldName: "Amount",
            type: "currency",
            sortable: "true"
        },
        {
            label: "Rec Submitted Date",
            fieldName: "Rec_Submitted__c",
            type: "date",
            sortable: "true"
        }
    ];

    renderedCallback() {
        // Set the width based on the current window
        this.template.querySelector('[data-id="global-map-iframe"]').width =
            window.innerWidth - 75;
        this.template.querySelector('[data-id="us-map-iframe"]').width =
            window.innerWidth - 75;
    }

    async connectedCallback() {
        let [vfDomain, grantYears, focusAreas, investigators] =
            await Promise.all([
                getVFDomain(),
                getGrantYearsData(),
                getFocusAreasData(),
                getInvestigatorData()
            ]);

        //Add listener for region clicks on VF Maps
        window.addEventListener("message", this.handleRegionClick.bind(this));
        this.vfDomain = vfDomain;

        grantYears = JSON.parse(grantYears);
        focusAreas = JSON.parse(focusAreas);
        investigators = JSON.parse(investigators);

        this.availableGrantYears = [];
        for (let val in grantYears) {
            let count = grantYears[val];
            let lbl = val + " (" + count + ")";
            this.availableGrantYears.push({ label: lbl, value: val });
            this.allYears.push(val);
        }

        this.availableFocusAreas = [];
        for (let val in focusAreas) {
            let count = focusAreas[val];
            let lbl = val + " (" + count + ")";
            this.availableFocusAreas.push({ label: lbl, value: val });
            this.allFocusAreas.push(val);
        }

        this.availableInvestigators = [];
        for (let val in investigators) {
            let count = investigators[val];
            let lbl = val + " (" + count + ")";
            this.availableInvestigators.push({ label: lbl, value: val });
            this.allInvestigators.push(val);
        }

        this.loadGranteeData();
        this.isLoading = false;

        this.selectedInvestigators = [];
        this.selectedFocusAreas = [];
        this.selectedGrantYears = [];
    }

    disconnectedCallback() {
        window.removeEventListener("message", this.handleRegionClick);
    }

    async loadGranteeData(loadAll) {
        let grantYearsToFilter;
        let focusAreasToFilter;
        let investigatorsToFilter;

        if (this.yearFiltersApplied) {
            grantYearsToFilter = this.selectedGrantYears;
        } else {
            grantYearsToFilter = this.allYears;
        }

        if (this.focusFiltersApplied) {
            focusAreasToFilter = this.selectedFocusAreas;
        } else {
            focusAreasToFilter = this.allFocusAreas;
        }

        if (this.investigatorFiltersApplied) {
            investigatorsToFilter = this.selectedInvestigators;
        } else {
            investigatorsToFilter = this.allInvestigators;
        }

        let [globalGrantees, usGrantees] = await Promise.all([
            getGlobalGranteeDetail({
                filteredGrantYears: grantYearsToFilter,
                filteredFocusAreas: focusAreasToFilter,
                filteredInvestigators: investigatorsToFilter
            }),
            getUSGranteeDetail({
                filteredGrantYears: grantYearsToFilter,
                filteredFocusAreas: focusAreasToFilter,
                filteredInvestigators: investigatorsToFilter
            })
        ]);

        this.globalMapOpps = this.updateGlobalGranteeData(
            JSON.parse(globalGrantees)
        );
        this.usMapOpps = this.updateUSGranteeData(JSON.parse(usGrantees));
    }

    async redrawUSMap() {
        var UsMapIframe = this.template.querySelector(
            '[data-id="us-map-iframe"]'
        ).contentWindow;
        UsMapIframe.postMessage({ name: "redraw" }, this.vfDomain);
    }

    async handleRegionClick(message) {
        this.vfDomain = await getVFDomain();
        if (message.origin !== this.vfDomain) {
            //Not the expected origin
            return;
        }
        //handle the message
        if (message.data.name === "globalMapRegionClick") {
            this.filterGlobalDetailData(message.data.payload);
        } else if (message.data.name === "usMapRegionClick") {
            this.filterUSDetailData(message.data.payload);
        }
    }

    filterUSDetailData(stateCode) {
        let filteredList = this.usMapOpps.filter(function (opp) {
            let state = "US-" + opp.stateCode;
            return state === stateCode; //the payload sends up the state abbreviation prepended with US-
        });
        this.filteredUsMapOpps = this.doSort(
            filteredList,
            this.usSortedBy,
            this.usSortedDirection
        );
    }

    filterGlobalDetailData(countryCode) {
        if (countryCode === "US") {
            this.showUSMap();
        } else {
            this.hideUSMap();
        }
        let filteredList = this.globalMapOpps.filter(function (opp) {
            return opp.CountryCode === countryCode;
        });
        this.filteredGlobalMapOpps = this.doSort(
            filteredList,
            this.globalSortedBy,
            this.globalSortedDirection
        );
    }

    hideUSMap() {
        this.template
            .querySelector('[data-id="USSection"]')
            .classList.add("hidden-elements");
    }

    showUSMap() {
        this.template
            .querySelector('[data-id="USSection"]')
            .classList.remove("hidden-elements");
        this.redrawUSMap();
    }

    updateUSGranteeData(granteeData) {
        let location = window.location.origin;
        let oppLinkBase = location + "/lightning/r/Opportunity/";
        for (let opp of granteeData) {
            opp.AccountName = opp.Account.Name;
            opp.RecordURL = oppLinkBase + opp.Id + "/view";
            if (
                opp.Grant_Investigator_User__r &&
                opp.Grant_Investigator_User__r.Name
            ) {
                opp.GrantInvestigator = opp.Grant_Investigator_User__r.Name;
            }
            if (
                opp.Mapping_Override_Address__c &&
                opp.Mapping_Override_Address__c.stateCode
            ) {
                opp.stateCode = opp.Mapping_Override_Address__c.stateCode;
            } else if (opp.Account && opp.Account.BillingStateCode) {
                opp.stateCode = opp.Account.BillingStateCode;
            }
        }
        return granteeData;
    }

    updateGlobalGranteeData(granteeData) {
        let location = window.location.origin;
        let oppLinkBase = location + "/lightning/r/Opportunity/";
        for (let opp of granteeData) {
            opp.AccountName = opp.Account.Name;
            opp.RecordURL = oppLinkBase + opp.Id + "/view";
            if (
                opp.Grant_Investigator_User__r &&
                opp.Grant_Investigator_User__r.Name
            ) {
                opp.GrantInvestigator = opp.Grant_Investigator_User__r.Name;
            }
            if (
                opp.Mapping_Override_Address__c &&
                opp.Mapping_Override_Address__c.countryCode
            ) {
                opp.CountryCode = opp.Mapping_Override_Address__c.countryCode;
            } else if (opp.Account && opp.Account.BillingCountryCode) {
                opp.CountryCode = opp.Account.BillingCountryCode;
            }
        }
        return granteeData;
    }

    async grantYearsChanged(event) {
        this.yearFiltersApplied = true;

        this.selectedGrantYears = event.detail.value;

        var globalMapIframe = this.template.querySelector(
            '[data-id="global-map-iframe"]'
        ).contentWindow;
        var UsMapIframe = this.template.querySelector(
            '[data-id="us-map-iframe"]'
        ).contentWindow;

        globalMapIframe.postMessage(
            { name: "grantYears", payload: this.selectedGrantYears },
            this.vfDomain
        );
        UsMapIframe.postMessage(
            { name: "grantYears", payload: this.selectedGrantYears },
            this.vfDomain
        );

        await this.loadGranteeData();
        this.resetStartingData();

        // Show filtered data
        this.filteredGlobalMapOpps = this.doSort(
            this.globalMapOpps,
            this.globalSortedBy,
            this.globalSortedDirection
        );
        this.filteredUsMapOpps = this.doSort(
            this.usMapOpps,
            this.usSortedBy,
            this.usSortedDirection
        );
    }

    async focusAreasChanged(event) {
        this.focusFiltersApplied = true;
        this.selectedFocusAreas = event.detail.value;

        var globalMapIframe = this.template.querySelector(
            '[data-id="global-map-iframe"]'
        ).contentWindow;
        var UsMapIframe = this.template.querySelector(
            '[data-id="us-map-iframe"]'
        ).contentWindow;

        globalMapIframe.postMessage(
            { name: "focusAreas", payload: this.selectedFocusAreas },
            this.vfDomain
        );
        UsMapIframe.postMessage(
            { name: "focusAreas", payload: this.selectedFocusAreas },
            this.vfDomain
        );

        await this.loadGranteeData();
        this.resetStartingData();

        // Show filtered data
        this.filteredGlobalMapOpps = this.doSort(
            this.globalMapOpps,
            this.globalSortedBy,
            this.globalSortedDirection
        );
        this.filteredUsMapOpps = this.doSort(
            this.usMapOpps,
            this.usSortedBy,
            this.usSortedDirection
        );
    }

    async investigatorsChanged(event) {
        this.investigatorFiltersApplied = true;

        this.selectedInvestigators = event.detail.value;

        var globalMapIframe = this.template.querySelector(
            '[data-id="global-map-iframe"]'
        ).contentWindow;
        var UsMapIframe = this.template.querySelector(
            '[data-id="us-map-iframe"]'
        ).contentWindow;

        globalMapIframe.postMessage(
            { name: "investigators", payload: this.selectedInvestigators },
            this.vfDomain
        );
        UsMapIframe.postMessage(
            { name: "investigators", payload: this.selectedInvestigators },
            this.vfDomain
        );

        await this.loadGranteeData();
        this.resetStartingData();

        // Show filtered data
        this.filteredGlobalMapOpps = this.doSort(
            this.globalMapOpps,
            this.globalSortedBy,
            this.globalSortedDirection
        );
        this.filteredUsMapOpps = this.doSort(
            this.usMapOpps,
            this.usSortedBy,
            this.usSortedDirection
        );
    }

    handleGlobalSort(event) {
        // assign the latest attribute with the sorted column fieldName and sorted direction
        let fieldName = event.detail.fieldName;
        let sortDirection = event.detail.sortDirection;
        this.globalSortedBy = fieldName;
        this.globalSortedDirection = sortDirection;

        let parseData = JSON.parse(JSON.stringify(this.filteredGlobalMapOpps));
        this.filteredGlobalMapOpps = this.doSort(
            parseData,
            fieldName,
            sortDirection
        );
    }

    handleUSSort(event) {
        let fieldName = event.detail.fieldName;
        let sortDirection = event.detail.sortDirection;
        this.usSortedBy = fieldName;
        this.usSortedDirection = sortDirection;

        let parseData = JSON.parse(JSON.stringify(this.filteredUsMapOpps));
        this.filteredUsMapOpps = this.doSort(
            parseData,
            fieldName,
            sortDirection
        );
    }

    doSort(data, fieldName, sortDirection) {
        // If the fieldName is RecordURL, we want to actually sort by the Opportunity Name (the value is the URL)
        if (fieldName === "RecordURL") {
            fieldName = "Name";
        }
        // checking reverse direction
        let isReverse = sortDirection === "asc" ? 1 : -1;
        data.sort((a, b) => {
            a = a[fieldName] ? a[fieldName] : ""; // Handle null values
            b = b[fieldName] ? b[fieldName] : "";

            return a > b ? 1 * isReverse : -1 * isReverse;
        });
        return data;
    }

    resetStartingData() {
        // Reset Filter Data
        this.filteredGlobalMapOpps = null;
        this.filteredUsMapOpps = null;
        this.globalSortedBy = "AccountName";
        this.globalSortedDirection = "asc";
        this.usSortedBy = "AccountName";
        this.usSortedDirection = "asc";
    }
}
