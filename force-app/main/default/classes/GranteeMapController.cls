public with sharing class GranteeMapController {
    private Map<String, Integer> granteesByCountry;
    private Map<String, Integer> usGranteesByState;

    public List<String> filteredGrantYears = new List<String>{};
    public List<String> filteredFocusAreas = new List<String>{};
    public List<String> filteredInvestigators = new List<String>{};

    public GranteeMapController() {
        //Initialize filter groups to begin with all selected
        filteredGrantYears = (List<String>) JSON.deserialize(
            GranteeMapController.getGrantYears(),
            List<String>.class
        );
        filteredFocusAreas = (List<String>) JSON.deserialize(
            GranteeMapController.getFocusAreas(),
            List<String>.class
        );
        filteredInvestigators = (List<String>) JSON.deserialize(
            GranteeMapController.getInvestigators(),
            List<String>.class
        );
        granteesByCountry = this.getGranteesByCountry();
        usGranteesByState = this.getUSGranteesByState();
    }

    @AuraEnabled
    public static string getFocusAreas() {
        try {
            List<AggregateResult> oppsByFocusArea = loadFocusAreas();
            List<String> focusAreas = new List<String>();
            for (AggregateResult ar : oppsByFocusArea) {
                focusAreas.add(String.valueOf(ar.get('Focus_Area__c')));
            }
            // add a null area to include opps without a focus area
            focusAreas.add('');
            return JSON.serialize(focusAreas);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static string getFocusAreasData() {
        try {
            List<AggregateResult> oppsByFocusArea = loadFocusAreas();
            Map<String, Integer> oppCountsByFocusArea = new Map<String, Integer>();
            for (AggregateResult ar : oppsByFocusArea) {
                if (ar.get('Focus_Area__c') == null) {
                    oppCountsByFocusArea.put(
                        'None',
                        Integer.valueOf(ar.get('totalOpps'))
                    );
                } else {
                    oppCountsByFocusArea.put(
                        String.valueOf(ar.get('Focus_Area__c')),
                        Integer.valueOf(ar.get('totalOpps'))
                    );
                }
            }
            return JSON.serialize(oppCountsByFocusArea);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static string getInvestigators() {
        try {
            List<AggregateResult> oppsByInvestigator = loadInvestigators();

            List<String> investigators = new List<String>();
            for (AggregateResult ar : oppsByInvestigator) {
                investigators.add(String.valueOf(ar.get('Name')));
            }
            return JSON.serialize(investigators);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static string getInvestigatorData() {
        try {
            List<AggregateResult> oppsByInvestigator = loadInvestigators();

            Map<String, Integer> oppCountsByInvestigator = new Map<String, Integer>();

            for (AggregateResult ar : oppsByInvestigator) {
                if (ar.get('Name') == null) {
                    oppCountsByInvestigator.put(
                        'None',
                        Integer.valueOf(ar.get('totalOpps'))
                    );
                } else {
                    oppCountsByInvestigator.put(
                        String.valueOf(ar.get('Name')),
                        Integer.valueOf(ar.get('totalOpps'))
                    );
                }
            }
            return JSON.serialize(oppCountsByInvestigator);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static string getGlobalGranteeDetail(
        List<String> filteredGrantYears,
        List<String> filteredFocusAreas,
        List<String> filteredInvestigators
    ) {
        try {
            List<Opportunity> filteredGrantees = loadGlobalGrantees(
                filteredGrantYears,
                filteredFocusAreas,
                filteredInvestigators
            );
            return JSON.serialize(filteredGrantees);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static string getUSGranteeDetail(
        List<String> filteredGrantYears,
        List<String> filteredFocusAreas,
        List<String> filteredInvestigators
    ) {
        try {
            List<Opportunity> filteredGrantees = loadUSGrantees(
                filteredGrantYears,
                filteredFocusAreas,
                filteredInvestigators
            );
            return JSON.serialize(filteredGrantees);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static string getGrantYears() {
        try {
            List<AggregateResult> oppsByYear = loadGrantYears();
            List<String> grantYears = new List<String>();
            for (AggregateResult ar : oppsByYear) {
                grantYears.add(String.valueOf(ar.get('year')));
            }
            return JSON.serialize(grantYears);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static string getGrantYearsData() {
        try {
            List<AggregateResult> oppsByYear = loadGrantYears();
            Map<String, Integer> oppCountsByYear = new Map<String, Integer>();
            for (AggregateResult ar : oppsByYear) {
                if (ar.get('year') == null) {
                    oppCountsByYear.put(
                        'None',
                        Integer.valueOf(ar.get('totalOpps'))
                    );
                } else {
                    oppCountsByYear.put(
                        String.valueOf(ar.get('year')),
                        Integer.valueOf(ar.get('totalOpps'))
                    );
                }
            }
            return JSON.serialize(oppCountsByYear);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    public Map<String, Integer> getGranteesByCountry() {
        List<Opportunity> grantOpportunities = loadGlobalGrantees(
            this.filteredGrantYears,
            this.filteredFocusAreas,
            this.filteredInvestigators
        );

        Map<String, Integer> countryMap = new Map<String, Integer>();

        for (Opportunity opp : grantOpportunities) {
            // Custom address fields cannot be filtered on, look for the presence of an override country in the returned data before moving on to the account address field
            String country;
            if (
                opp.Mapping_Override_Address__c != null &&
                opp.Mapping_Override_Address__c.getCountryCode() != null
            ) {
                country = opp.Mapping_Override_Address__c.getCountryCode();
            } else if (opp.Account.BillingCountryCode != null) {
                country = opp.Account.BillingCountryCode;
            }

            // If a country was found in the Opp or secondarily in the Account, add it to the Country Map
            if (country != null) {
                if (countryMap.containsKey(country)) {
                    Integer currentTotal = countryMap.get(country);
                    currentTotal += Integer.valueOf(opp.Amount);
                    countryMap.put(country, currentTotal);
                } else {
                    countryMap.put(country, Integer.valueOf(opp.Amount));
                }
            }
        }

        return countryMap;
    }

    public static List<Opportunity> loadGlobalGrantees(
        List<String> filteredGrantYears,
        List<String> filteredFocusAreas,
        List<String> filteredInvestigators
    ) {
        List<Opportunity> grantOpportunities = getOpportunityQueryWithFilters(
            filteredFocusAreas,
            filteredInvestigators
        );

        Boolean yearsIncludesNull = false;

        for (String yr : filteredGrantYears) {
            if (String.isBlank(yr)) {
                yearsIncludesNull = true;
            }
        }

        List<Opportunity> oppsInFilter = new List<Opportunity>();
        if (filteredGrantYears != null) {
            for (Opportunity opp : grantOpportunities) {
                String country;
                if (
                    opp.Mapping_Override_Address__c != null &&
                    opp.Mapping_Override_Address__c.getCountryCode() != null
                ) {
                    country = opp.Mapping_Override_Address__c.getCountryCode();
                } else if (opp.Account.BillingCountryCode != null) {
                    country = opp.Account.BillingCountryCode;
                }

                // only apply year filter if the account has a country code
                if (country != null) {
                    if (yearsIncludesNull && opp.Rec_Submitted__c == null) {
                        oppsInFilter.add(opp);
                    } else {
                        for (String yearString : filteredGrantYears) {
                            if (
                                opp.Rec_Submitted__c != null &&
                                String.isNotBlank(yearString) &&
                                opp.Rec_Submitted__c.Year() ==
                                Integer.valueOf(yearString)
                            ) {
                                oppsInFilter.add(opp);
                                break;
                            }
                        }
                    }
                }
            }
        } else {
            oppsInFilter.addAll(grantOpportunities);
        }

        return oppsInFilter;
    }

    public static List<Opportunity> loadUSGrantees(
        List<String> filteredGrantYears,
        List<String> filteredFocusAreas,
        List<String> filteredInvestigators
    ) {
        List<Opportunity> grantOpportunities = getOpportunityQueryWithFilters(
            filteredFocusAreas,
            filteredInvestigators
        );

        Boolean yearsIncludesNull = false;

        for (String yr : filteredGrantYears) {
            if (String.isBlank(yr)) {
                yearsIncludesNull = true;
            }
        }

        List<Opportunity> oppsInFilter = new List<Opportunity>();
        for (Opportunity opp : grantOpportunities) {
            // Custom address fields cannot be filtered on, look for the presence of an override country in the returned data before moving on to the account address field
            String state;
            if (
                opp.Mapping_Override_Address__c != null &&
                opp.Mapping_Override_Address__c.getState() != null
            ) {
                state = opp.Mapping_Override_Address__c.getState();
            } else if (opp.Account.BillingCountry != null) {
                if (
                    opp.Account.BillingCountry == 'United States' &&
                    opp.Account.BillingState != null
                ) {
                    state = opp.Account.BillingState;
                }
            }

            if (state != null) {
                // now apply year filters (which can't be incorporated into the initial query)
                if (yearsIncludesNull && opp.Rec_Submitted__c == null) {
                    oppsInFilter.add(opp);
                } else {
                    for (String yearString : filteredGrantYears) {
                        if (
                            opp.Rec_Submitted__c != null &&
                            String.isNotBlank(yearString) &&
                            opp.Rec_Submitted__c.Year() ==
                            Integer.valueOf(yearString)
                        ) {
                            oppsInFilter.add(opp);
                            break;
                        }
                    }
                }
            }
        }

        return oppsInFilter;
    }

    public Map<String, Integer> getUSGranteesByState() {
        List<Opportunity> grantOpportunities = loadUSGrantees(
            this.filteredGrantYears,
            this.filteredFocusAreas,
            this.filteredInvestigators
        );

        Map<String, Integer> stateMap = new Map<String, Integer>();

        for (Opportunity opp : grantOpportunities) {
            String state;
            if (
                opp.Mapping_Override_Address__c != null &&
                opp.Mapping_Override_Address__c.getState() != null
            ) {
                state = opp.Mapping_Override_Address__c.getState();
            } else if (opp.Account.BillingCountry != null) {
                if (
                    opp.Account.BillingCountry == 'United States' &&
                    opp.Account.BillingState != null
                ) {
                    state = opp.Account.BillingState;
                }
            }

            if (state != null) {
                if (stateMap.containsKey(state)) {
                    Integer currentTotal = stateMap.get(state);
                    currentTotal += Integer.valueOf(opp.Amount);
                    stateMap.put(state, currentTotal);
                } else {
                    stateMap.put(state, Integer.valueOf(opp.Amount));
                }
            }
        }

        return stateMap;
    }

    @AuraEnabled
    public static string getVFDomain() {
        try {
            String vfHostname = DomainCreator.getVisualforceHostname(null);
            vfHostname = 'https://' + vfHostname;
            return vfHostname;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    public String getLexOrigin() {
        String myLightningHostname = DomainCreator.getLightningHostname();
        myLightningHostname = 'https://' + myLightningHostname;
        return myLightningHostname;
    }

    public static List<AggregateResult> loadGrantYears() {
        return [
            SELECT CALENDAR_YEAR(Rec_Submitted__c) year, COUNT(Name) totalOpps
            FROM Opportunity
            WHERE
                IsClosed = TRUE
                AND IsWon = TRUE
                AND Rec_Submitted__c != NULL
                AND Grant_Investigator_User__c != NULL
            GROUP BY CALENDAR_YEAR(Rec_Submitted__c)
            ORDER BY CALENDAR_YEAR(Rec_Submitted__c) DESC
        ];
    }

    // Calling this function from the VF page will trigger a re-render, which is all that's needed.
    public void resize() {
    }

    public void setFilteredGrantYears() {
        string passedVariableString = system.CurrentPageReference()
            .getParameters()
            .get('years');

        List<String> passedInYears = (List<String>) JSON.deserialize(
            passedVariableString,
            List<String>.class
        );

        this.filteredGrantYears = passedInYears;
        this.granteesByCountry = getGranteesByCountry();
        this.usGranteesByState = getUSGranteesByState();
    }

    public void setFilteredFocusAreas() {
        string passedVariableString = system.CurrentPageReference()
            .getParameters()
            .get('focuses');

        List<String> passedInFocuses = (List<String>) JSON.deserialize(
            passedVariableString,
            List<String>.class
        );

        this.filteredFocusAreas = passedInFocuses;
        this.granteesByCountry = getGranteesByCountry();
        this.usGranteesByState = getUSGranteesByState();
    }

    public void setFilteredInvestigators() {
        string passedVariableString = system.CurrentPageReference()
            .getParameters()
            .get('investigators');

        List<String> passedInInvestigators = (List<String>) JSON.deserialize(
            passedVariableString,
            List<String>.class
        );

        this.filteredInvestigators = passedInInvestigators;
        this.granteesByCountry = getGranteesByCountry();
        this.usGranteesByState = getUSGranteesByState();
    }

    private static List<Opportunity> getOpportunityQueryWithFilters(
        List<String> filteredFocusAreas,
        List<String> filteredInvestigators
    ) {
        Boolean focusAreasIncludesNull = false;
        Boolean investigatorsIncludesNull = false;

        for (String foc : filteredFocusAreas) {
            if (foc == 'None') {
                focusAreasIncludesNull = true;
            }
        }

        for (String inv : filteredInvestigators) {
            if (inv == 'None') {
                investigatorsIncludesNull = true;
            }
        }

        String fieldsToQuery = 'ID, Name, Amount, Mapping_Override_Address__c, Account.BillingCountry, Account.BillingCountryCode, Account.Name, Account.BillingState, Account.BillingStateCode, Rec_Submitted__c, Grant_Investigator_User__r.Name, Focus_Area__c';
        String filteredWhereClause = 'IsClosed=TRUE AND Rec_Submitted__c!=null AND IsWon=TRUE';

        // Handle filtering on null/empty values
        if (focusAreasIncludesNull) {
            filteredWhereClause =
                filteredWhereClause +
                ' AND (Focus_Area__c in:filteredFocusAreas OR Focus_Area__c = null)';
        } else {
            filteredWhereClause =
                filteredWhereClause +
                ' AND Focus_Area__c in:filteredFocusAreas';
        }

        if (investigatorsIncludesNull) {
            filteredWhereClause =
                filteredWhereClause +
                ' AND (Grant_Investigator_User__r.Name in:filteredInvestigators OR Grant_Investigator_User__c = null)';
        } else {
            filteredWhereClause =
                filteredWhereClause +
                ' AND Grant_Investigator_User__r.Name in:filteredInvestigators';
        }

        String q = // Use dynamic SOQL to get all fields.
            'SELECT ' +
            fieldsToQuery +
            ' FROM Opportunity' +
            ' WHERE ' +
            filteredWhereClause +
            ' ORDER BY Rec_Submitted__c DESC';

        return Database.query(q);
    }

    private static List<AggregateResult> loadInvestigators() {
        return [
            SELECT Grant_Investigator_User__r.Name, COUNT(Name) totalOpps
            FROM Opportunity
            WHERE IsClosed = TRUE AND IsWon = TRUE AND Rec_Submitted__c != NULL
            GROUP BY Grant_Investigator_User__r.Name
        ];
    }

    private static List<AggregateResult> loadFocusAreas() {
        return [
            SELECT Focus_Area__c, COUNT(Name) totalOpps
            FROM Opportunity
            WHERE IsClosed = TRUE AND IsWon = TRUE AND Rec_Submitted__c != NULL
            GROUP BY Focus_Area__c
        ];
    }
}
