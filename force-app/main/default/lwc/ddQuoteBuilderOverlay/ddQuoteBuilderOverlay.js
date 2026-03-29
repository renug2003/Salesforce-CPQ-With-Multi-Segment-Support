import { LightningElement, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { MessageContext, subscribe, unsubscribe } from 'lightning/messageService';
import DD_SHOW_QUOTE_BUILDER from '@salesforce/messageChannel/DDShowQuoteBuilder__c';

const STORAGE_KEY = 'ddQuoteBuilderTarget';

/**
 * Two activation paths:
 *
 * 1. Same-page (Opportunity "New Quote"):
 *    ddOppQuoteAction publishes LMS message DDShowQuoteBuilder__c with
 *    { recordId }.  The overlay subscribes and shows the Quote Builder.
 *
 * 2. Cross-page (Account "New Quote"):
 *    ddNewQuoteAction writes the new Opp Id to sessionStorage, then
 *    navigates to the Opportunity record.  When the overlay mounts on that
 *    new page, @wire(CurrentPageReference) fires, it reads sessionStorage,
 *    finds the match, and shows the Quote Builder.
 */
export default class DdQuoteBuilderOverlay extends LightningElement {
    recordId;
    isQuoteMode = false;
    _subscription = null;

    @wire(MessageContext)
    messageContext;

    connectedCallback() {
        this._subscribeToLms();
    }

    disconnectedCallback() {
        unsubscribe(this._subscription);
        this._subscription = null;
    }

    _subscribeToLms() {
        if (this._subscription) return;
        this._subscription = subscribe(
            this.messageContext,
            DD_SHOW_QUOTE_BUILDER,
            (message) => {
                if (message?.recordId && message.recordId === this.recordId) {
                    this.isQuoteMode = true;
                }
            }
        );
    }

    @wire(CurrentPageReference)
    pageRef(ref) {
        const id = ref?.attributes?.recordId ?? null;
        if (!id) return;
        this.recordId = id;

        // Cross-page path: Account "New Quote" stored this id before navigating
        const target = sessionStorage.getItem(STORAGE_KEY);
        if (target === id) {
            sessionStorage.removeItem(STORAGE_KEY);
            this.isQuoteMode = true;
        }
    }
}
