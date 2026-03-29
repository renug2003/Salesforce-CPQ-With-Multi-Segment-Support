import { LightningElement, api, wire } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { MessageContext, publish } from 'lightning/messageService';
import DD_SHOW_QUOTE_BUILDER from '@salesforce/messageChannel/DDShowQuoteBuilder__c';

/**
 * Quick Action on Opportunity.
 * Publishes an LMS message so ddQuoteBuilderOverlay opens the Quote Builder
 * in the main column, then closes this modal — no navigation required.
 */
export default class DdOppQuoteAction extends LightningElement {

    @api recordId;

    @wire(MessageContext)
    messageContext;

    connectedCallback() {
        // Defer one microtask so the action framework fully initialises
        Promise.resolve().then(() => {
            if (!this.recordId) return;
            publish(this.messageContext, DD_SHOW_QUOTE_BUILDER, { recordId: this.recordId });
            this.dispatchEvent(new CloseActionScreenEvent());
        });
    }
}
