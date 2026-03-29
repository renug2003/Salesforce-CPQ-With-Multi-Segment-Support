import { LightningElement, api, track } from 'lwc';
import createQuoteOpportunity from '@salesforce/apex/DDQuoteBuilderController.createQuoteOpportunity';

/**
 * Inline quote wizard embedded directly on the Account Record Page.
 * No popup — the wizard renders in the page's main content area.
 */
export default class DdAccountQuotePanel extends LightningElement {

    /** Account Id — set automatically by the record page */
    @api recordId;

    @track showWizard   = false;
    @track isCreating   = false;
    @track oppId        = null;
    @track errorMessage = null;

    async handleStartQuote() {
        this.isCreating   = true;
        this.errorMessage = null;
        try {
            this.oppId      = await createQuoteOpportunity({ accountId: this.recordId });
            this.showWizard = true;
        } catch (e) {
            this.errorMessage = e.body?.message || e.message || 'Failed to create quote. Please try again.';
        } finally {
            this.isCreating = false;
        }
    }

    handleWizardClose() {
        this.showWizard = false;
        this.oppId      = null;
    }

    handleDismissError() { this.errorMessage = null; }

    get hasError()    { return !!this.errorMessage; }
    get showHero()    { return !this.showWizard && !this.isCreating; }
}
