import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getBindSummary from '@salesforce/apex/DDPolicyBindController.getBindSummary';
import bindPolicy    from '@salesforce/apex/DDPolicyBindController.bindPolicy';

export default class DdBindPolicy extends NavigationMixin(LightningElement) {

    @api recordId; // Quote Id when used as a record action

    @track isLoading  = false;
    @track errorMessage;
    @track summary;
    @track result;
    @track bound      = false;
    @track selectedProposalIds = [];

    connectedCallback() {
        this._load();
    }

    async _load() {
        this.isLoading = true;
        try {
            this.summary = await getBindSummary({ quoteId: this.recordId });
            this.selectedProposalIds = (this.summary.proposals || []).map(p => p.id);
        } catch (e) {
            this.errorMessage = e.body?.message || e.message || 'Failed to load summary.';
        } finally {
            this.isLoading = false;
        }
    }

    get showConfirm() { return !this.bound && !this.isLoading && this.summary; }

    get formattedTotalPremium() {
        if (!this.summary) return '';
        return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' })
            .format(this.summary.totalPremium || 0);
    }

    get groupUrl()  { return this.result ? `/lightning/r/DD_Group__c/${this.result.groupId}/view`  : '#'; }
    get policyUrl() { return this.result ? `/lightning/r/DD_Policy__c/${this.result.policyId}/view` : '#'; }

    handleProposalToggle(e) {
        const id = e.target.dataset.id;
        if (e.target.checked) {
            if (!this.selectedProposalIds.includes(id)) this.selectedProposalIds = [...this.selectedProposalIds, id];
        } else {
            this.selectedProposalIds = this.selectedProposalIds.filter(i => i !== id);
        }
    }

    async handleBind() {
        this.isLoading = true;
        this.errorMessage = null;
        try {
            this.result = await bindPolicy({
                quoteId: this.recordId,
                proposalIds: this.selectedProposalIds
            });
            this.bound = true;
        } catch (e) {
            this.errorMessage = e.body?.message || e.message || 'Bind failed.';
        } finally {
            this.isLoading = false;
        }
    }

    handleCancel() { this.dispatchEvent(new CustomEvent('close')); }

    handleDone() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: this.result.policyId, actionName: 'view' }
        });
    }
}
