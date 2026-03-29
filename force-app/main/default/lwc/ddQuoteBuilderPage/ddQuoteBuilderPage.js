import { LightningElement, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';

/**
 * Full-page container for the DD Quote Builder.
 * Reads the Opportunity Id from the page state (c__recordId) so it can be
 * launched via NavigationMixin from both the Account and Opportunity Quick Actions.
 */
export default class DdQuoteBuilderPage extends LightningElement {
    recordId;

    @wire(CurrentPageReference)
    pageRef(ref) {
        if (ref?.state?.c__recordId) {
            this.recordId = ref.state.c__recordId;
        }
    }
}
