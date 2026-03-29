import LightningModal from 'lightning/modal';
import { api } from 'lwc';

/**
 * Full-screen LightningModal that wraps the quote wizard.
 * Opened programmatically from ddNewQuoteAction after the Opp is created.
 * Because LightningModal renders at the app level (not inside the calling
 * component), it persists after the quick-action modal is closed.
 */
export default class DdQuoteWizardModal extends LightningModal {

    /** Opportunity Id created by ddNewQuoteAction */
    @api oppId;

    handleWizardClose() {
        this.close('done');
    }
}
