import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import getBindSummary from '@salesforce/apex/DDPolicyBindController.getBindSummary';
import bindPolicy    from '@salesforce/apex/DDPolicyBindController.bindPolicy';

const fmt = val => new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(val || 0);

export default class DdBindPolicy extends NavigationMixin(LightningElement) {

    @api recordId;
    @track isLoading  = false;
    @track errorMessage;
    @track summary;
    @track result;
    @track bound    = false;
    // Map of proposalId → 'pending' | 'accepted' | 'rejected'
    _decisions = {};
    _recordId;
    _loaded = false;

    @wire(CurrentPageReference)
    wiredPageRef(pageRef) {
        const id = this.recordId
            || pageRef?.state?.recordId
            || pageRef?.attributes?.recordId;
        if (id && !this._loaded) {
            this._loaded  = true;
            this._recordId = id;
            this._load();
        }
    }

    async _load() {
        this.isLoading = true;
        try {
            this.summary = await getBindSummary({ quoteId: this._recordId });
            // Initialise all proposals as pending
            this._decisions = {};
            (this.summary.proposals || []).forEach(p => {
                this._decisions[p.id] = 'pending';
            });
        } catch (e) {
            this.errorMessage = e.body?.message || e.message || 'Failed to load summary.';
        } finally {
            this.isLoading = false;
        }
    }

    // ── Computed ──────────────────────────────────────────────────────────────

    get showConfirm() { return !this.bound && !this.isLoading && !!this.summary; }

    get formattedTotalPremium() { return fmt(this.summary?.totalPremium); }

    get proposalRows() {
        if (!this.summary) return [];
        return (this.summary.proposals || []).map(p => {
            const dec = this._decisions[p.id] || 'pending';
            return {
                id:              p.id,
                name:            p.name,
                plan:            p.plan,
                formattedPremium: fmt(p.premium),
                isPending:       dec === 'pending',
                isAccepted:      dec === 'accepted',
                isRejected:      dec === 'rejected',
                rowClass:        'prop-row prop-row--' + dec
            };
        });
    }

    get hasPendingProposals() {
        return Object.values(this._decisions).some(d => d === 'pending');
    }

    get isBindDisabled() {
        if (this.isLoading) return true;
        if (this.hasPendingProposals) return true;
        // At least one must be accepted
        return !Object.values(this._decisions).some(d => d === 'accepted');
    }

    get groupUrl()  { return this.result ? `/lightning/r/DD_Group__c/${this.result.groupId}/view`  : '#'; }
    get policyUrl() { return this.result ? `/lightning/r/DD_Policy__c/${this.result.policyId}/view` : '#'; }

    // ── Handlers ──────────────────────────────────────────────────────────────

    handleAccept(e) { this._setDecision(e.target.dataset.id, 'accepted'); }
    handleReject(e) { this._setDecision(e.target.dataset.id, 'rejected'); }
    handleUndo(e)   { this._setDecision(e.target.dataset.id, 'pending');  }

    _setDecision(id, decision) {
        this._decisions = { ...this._decisions, [id]: decision };
    }

    async handleBind() {
        this.isLoading    = true;
        this.errorMessage = null;
        const accepted = Object.entries(this._decisions)
            .filter(([, d]) => d === 'accepted').map(([id]) => id);
        const rejected = Object.entries(this._decisions)
            .filter(([, d]) => d === 'rejected').map(([id]) => id);
        try {
            this.result = await bindPolicy({
                quoteId:            this._recordId,
                acceptedProposalIds: accepted,
                rejectedProposalIds: rejected
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
