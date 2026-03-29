import { LightningElement, track, wire } from 'lwc';
import { MessageContext, subscribe, unsubscribe, APPLICATION_SCOPE } from 'lightning/messageService';
import DD_SHOW_QUOTE_BUILDER from '@salesforce/messageChannel/DDShowQuoteBuilder__c';

/**
 * Invisible listener placed on the Account record page.
 * When ddNewQuoteAction publishes DDShowQuoteBuilder with the new Opp Id,
 * this component opens a full-screen SLDS modal with the quote wizard —
 * the user never leaves the Account page.
 */
export default class DdAccountQuoteOverlay extends LightningElement {

    @track isOpen = false;
    @track oppId  = null;

    _subscription = null;

    @wire(MessageContext)
    messageContext;

    connectedCallback() {
        // Subscribe once messageContext is available (wire sets it before connectedCallback)
        this._subscribe();
    }

    disconnectedCallback() {
        unsubscribe(this._subscription);
        this._subscription = null;
    }

    _subscribe() {
        if (this._subscription || !this.messageContext) return;
        this._subscription = subscribe(
            this.messageContext,
            DD_SHOW_QUOTE_BUILDER,
            (message) => this._handleMessage(message),
            { scope: APPLICATION_SCOPE }
        );
    }

    _handleMessage(message) {
        if (message?.recordId) {
            this.oppId  = message.recordId;
            this.isOpen = true;
        }
    }

    handleClose() {
        this.isOpen = false;
        this.oppId  = null;
    }
}
