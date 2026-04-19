import { LightningElement, api, wire, track } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getLatestAssessment           from '@salesforce/apex/RiskAssessmentController.getLatestAssessment';
import requestManualAssessment       from '@salesforce/apex/RiskAssessmentController.requestManualAssessment';
import hasManualAssessmentPermission from '@salesforce/apex/RiskAssessmentController.hasManualAssessmentPermission';
import searchOpportunities           from '@salesforce/apex/RiskAssessmentController.searchOpportunities';
import LABEL_TIMEOUT   from '@salesforce/label/c.Risk_Callout_Timeout';
import LABEL_LOW_RISK  from '@salesforce/label/c.Risk_Low_Recommendation';
import LABEL_HIGH_RISK from '@salesforce/label/c.Risk_High_Recommendation';
import LABEL_PENDING   from '@salesforce/label/c.Risk_Assessment_Pending';
import LABEL_NO_ASSESS from '@salesforce/label/c.Risk_No_Assessment';
import OPP_NAME_FIELD   from '@salesforce/schema/Opportunity.Name';
import OPP_AMOUNT_FIELD from '@salesforce/schema/Opportunity.Amount';

const POLL_INTERVAL_MS = 5000;

export default class OpportunityRiskDashboard extends LightningElement {
    @api recordId;

    @track assessment        = null;
    @track isLoading         = false;
    @track errorMessage      = null;
    @track canRequestManualAssessment = false;
    @track isRequestingAssessment = false;

    // Home page mode
    @track selectedOpportunityId = null;
    @track searchTerm      = '';
    @track searchResults   = [];

    labelPending    = LABEL_PENDING;
    labelNoAssessment = LABEL_NO_ASSESS;

    _pollTimer = null;
    _searchDebounce = null;

    get activeOpportunityId() {
        return this.recordId || this.selectedOpportunityId;
    }

    get isHomePageMode() {
        return !this.recordId;
    }

    get isSearchMode() {
        return this.isHomePageMode && !this.selectedOpportunityId;
    }

    get isDashboardMode() {
        return !!this.recordId || !!this.selectedOpportunityId;
    }

    get isError()        { return !this.isLoading && !!this.errorMessage; }
    get isNoAssessment() { return !this.isLoading && !this.errorMessage && !this.assessment; }
    get isPending()      { return !this.isLoading && !this.errorMessage && this.assessment?.Status__c === 'Pending'; }
    get isCompleted()    { return !this.isLoading && !this.errorMessage && this.assessment?.Status__c === 'Completed'; }

    get riskLevelBadgeClass() {
        const level = (this.assessment?.Risk_Level__c || 'Low').toLowerCase();
        return `risk-badge risk-badge--${level} slds-badge`;
    }

    get scoreBarStyle() {
        const score = this.assessment?.Risk_Score__c || 0;
        const color = score >= 75 ? '#c23934' : score >= 50 ? '#ff9900' : score >= 25 ? '#ffb75d' : '#04844b';
        return `width:${score}%;background-color:${color};`;
    }

    get hasRecommendation() {
        return !!this.assessment?.Recommendation__c;
    }

    get headlineList() {
        const rec = this.assessment?.Recommendation__c || '';
        return rec.split(' | ').filter(h => h.trim().length > 0);
    }

    get recommendationText() {
        const level = this.assessment?.Risk_Level__c;
        if (level === 'High' || level === 'Critical') return LABEL_HIGH_RISK;
        if (level === 'Low') return LABEL_LOW_RISK;
        return this.assessment?.Recommendation__c || '';
    }

    get recommendationBoxClass() {
        const level = (this.assessment?.Risk_Level__c || 'Low').toLowerCase();
        return `recommendation-box recommendation-box--${level} slds-p-around_small slds-m-top_small`;
    }

    @wire(getRecord, { recordId: '$recordId', fields: [OPP_NAME_FIELD, OPP_AMOUNT_FIELD] })
    wiredOpportunity({ error, data }) {
        if (data && this.recordId) {
            this.fetchAssessment();
        }
    }

    @wire(hasManualAssessmentPermission)
    wiredPermission({ data }) {
        if (data !== undefined) {
            this.canRequestManualAssessment = data;
        }
    }

    connectedCallback() {
        if (this.recordId) {
            this.fetchAssessment();
        }
    }

    disconnectedCallback() {
        this.stopPolling();
    }

    fetchAssessment() {
        const oppId = this.activeOpportunityId;
        if (!oppId) return;
        this.isLoading   = true;
        this.errorMessage = null;
        getLatestAssessment({ opportunityId: oppId })
            .then(result => {
                this.isLoading  = false;
                this.assessment = result;
                if (result && result.Status__c === 'Pending') {
                    this.startPolling();
                } else {
                    this.stopPolling();
                }
            })
            .catch(err => {
                this.isLoading    = false;
                this.errorMessage = err?.body?.message || LABEL_TIMEOUT;
                this.stopPolling();
            });
    }

    startPolling() {
        if (this._pollTimer) return;
        this._pollTimer = setInterval(() => {
            this.fetchAssessment();
        }, POLL_INTERVAL_MS);
    }

    stopPolling() {
        if (this._pollTimer) {
            clearInterval(this._pollTimer);
            this._pollTimer = null;
        }
    }

    handleSearchInput(event) {
        this.searchTerm = event.target.value;
        clearTimeout(this._searchDebounce);
        if (!this.searchTerm || this.searchTerm.length < 2) {
            this.searchResults = [];
            return;
        }
        this._searchDebounce = setTimeout(() => {
            searchOpportunities({ searchTerm: this.searchTerm })
                .then(results => { this.searchResults = results; })
                .catch(() => { this.searchResults = []; });
        }, 300);
    }

    handleSelectOpp(event) {
        const oppId = event.currentTarget.dataset.id;
        this.selectedOpportunityId = oppId;
        this.searchResults = [];
        this.fetchAssessment();
    }

    handleBack(event) {
        event.preventDefault();
        this.stopPolling();
        this.selectedOpportunityId = null;
        this.assessment    = null;
        this.errorMessage  = null;
        this.searchTerm    = '';
        this.searchResults = [];
    }

    handleRequestAssessment() {
        this.isRequestingAssessment = true;
        requestManualAssessment({ opportunityId: this.activeOpportunityId })
            .then(() => {
                this.isRequestingAssessment = false;
                this.fetchAssessment();
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Assessment Requested',
                    message: 'A new risk assessment has been queued.',
                    variant: 'success'
                }));
            })
            .catch(err => {
                this.isRequestingAssessment = false;
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: err?.body?.message || 'Could not request assessment.',
                    variant: 'error'
                }));
            });
    }
}
