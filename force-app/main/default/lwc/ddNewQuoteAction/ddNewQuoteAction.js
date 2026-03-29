import { LightningElement, api, track, wire } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { getRecord } from 'lightning/uiRecordApi';
import createQuoteOpportunity from '@salesforce/apex/DDQuoteBuilderController.createQuoteOpportunity';
import ACCOUNT_NAME from '@salesforce/schema/Account.Name';

/**
 * Quick Action on Account.
 * Uses @wire(getRecord) — the same pattern that previously worked for Opp creation.
 * When the wire fires, recordId is guaranteed to be set, so Apex receives a valid Id.
 * After creating the Opp, shows the full-screen wizard overlay (no navigation).
 */
export default class DdNewQuoteAction extends LightningElement {

    @api recordId;

    @track isCreating   = true;
    @track showWizard   = false;
    @track oppId        = null;
    @track errorMessage = null;

    _started = false;

    // Reactive to $recordId — fires once recordId is set by the quick-action framework
    @wire(getRecord, { recordId: '$recordId', fields: [ACCOUNT_NAME] })
    wiredAccount({ data, error }) {
        if (data && !this._started) {
            this._started = true;
            this._createOpportunity();
        } else if (error && !this._started) {
            this._started    = true;
            this.isCreating  = false;
            this.errorMessage = 'Failed to load account. Please refresh and try again.';
        }
    }

    async _createOpportunity() {
        try {
            this.oppId      = await createQuoteOpportunity({ accountId: this.recordId });
            this.isCreating = false;
            this.showWizard = true;
        } catch (e) {
            this.isCreating   = false;
            this.errorMessage = e.body?.message || e.message || 'An unexpected error occurred.';
        }
    }

    get hasError() { return !!this.errorMessage; }

    handleWizardClose() {
        this.showWizard = false;
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    handleClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}
