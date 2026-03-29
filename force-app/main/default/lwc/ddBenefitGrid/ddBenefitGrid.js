import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import getProductDetails from '@salesforce/apex/DDProductCatalogService.getProductDetails';

const PRODUCT_FIELDS = [
    'DD_Product__c.Name',
    'DD_Product__c.Product_Line__c',
    'DD_Product__c.DD_Product_Category__c'
];

// Sort arrows
const ARROW_NONE = '';
const ARROW_ASC  = ' ▲';
const ARROW_DESC = ' ▼';

export default class DdBenefitGrid extends LightningElement {
    @api recordId;

    @track _tabs = [];          // raw tab state objects
    @track isLoading = true;
    @track hasError  = false;
    @track hasData   = false;
    @track errorMessage = '';
    @track activeTabId = null;

    _productName     = '';
    _productLine     = '';
    _categoryName    = '';
    _isDhmo          = false;

    // ─── Wire: product record ──────────────────────────────────────────────────

    @wire(getRecord, { recordId: '$recordId', fields: PRODUCT_FIELDS })
    wiredProduct({ error, data }) {
        if (data) {
            this._productName  = getFieldValue(data, 'DD_Product__c.Name') || '';
            this._productLine  = getFieldValue(data, 'DD_Product__c.Product_Line__c') || '';
            this._categoryName = getFieldValue(data, 'DD_Product__c.DD_Product_Category__c') || '';
            this._isDhmo       = this._productLine === 'DHMO';
            this._loadBenefits();
        } else if (error) {
            this._setError('Failed to load product record: ' + this._extractMessage(error));
        }
    }

    // ─── Imperative load ──────────────────────────────────────────────────────

    _loadBenefits() {
        this.isLoading = true;
        getProductDetails({ productId: this.recordId })
            .then(detail => {
                this._buildTabs(detail);
                this.isLoading = false;
                this.hasData   = true;
            })
            .catch(err => {
                this._setError('Failed to load benefit schedule: ' + this._extractMessage(err));
            });
    }

    // ─── Tab construction ─────────────────────────────────────────────────────

    _buildTabs(detail) {
        const specs   = detail.coverageSpecs || [];
        const bySpec  = detail.benefitsBySpecId || {};

        const sorted = [...specs].sort((a, b) => (a.Display_Order__c || 0) - (b.Display_Order__c || 0));

        this._tabs = sorted.map((spec, idx) => {
            const rawBenefits = bySpec[spec.Id] || [];
            const allRows = rawBenefits.map((b, i) => this._buildRow(b, i));

            return {
                id:                   spec.Id,
                label:                spec.Coverage_Name__c || spec.Coverage_Code__c || `Coverage ${idx + 1}`,
                coinsurancePPO:       this._formatPct(spec.Coinsurance_PPO__c),
                coinsuranceNonPPO:    this._formatPct(spec.Coinsurance_NonPPO__c),
                deductibleApplies:    !!spec.Deductible_Applies__c,
                deductibleAppliesLabel: spec.Deductible_Applies__c ? 'Yes' : 'No',
                allRows,
                displayRows:          allRows,
                searchTerm:           '',
                hasSearch:            false,
                sortedBy:             'cdtCode',
                sortDirection:        'asc',
                totalCount:           allRows.length,
                filteredCount:        allRows.length,
                hasRows:              allRows.length > 0
            };
        });

        // Apply initial sort on each tab
        this._tabs = this._tabs.map(t => this._applySortToTab(t, t.sortedBy, t.sortDirection));

        if (this._tabs.length > 0) {
            this.activeTabId = this._tabs[0].id;
        }
    }

    _buildRow(b, idx) {
        return {
            id:                  b.Id || String(idx),
            cdtCode:             b.CDT_Code__c || '',
            description:         b.CDT_Description__c || '',
            frequencyDisplay:    this._formatFrequency(b.Frequency_Limit__c, b.Frequency_Period__c),
            ageRangeDisplay:     this._formatAgeRange(b.Age_Min__c, b.Age_Max__c),
            toothSpecificLabel:  b.Tooth_Specific__c ? '✓' : '—',
            requiresPreauthLabel: b.Requires_Preauth__c ? 'Yes' : 'No',
            copay11ALabel:       this._formatCopay(b.DHMO_Copay_11A__c),
            copay15BLabel:       this._formatCopay(b.DHMO_Copay_15B__c),
            copay17BLabel:       this._formatCopay(b.DHMO_Copay_17B__c),
            notesDisplay:        b.Notes__c || '',
            rowClass:            idx % 2 === 0 ? 'dd-row-even' : 'dd-row-odd'
        };
    }

    // ─── Getters ──────────────────────────────────────────────────────────────

    get productName()  { return this._productName; }
    get productLine()  { return this._productLine; }
    get categoryName() { return this._categoryName; }
    get isDhmo()       { return this._isDhmo; }
    get isDppo()       { return !this._isDhmo; }

    // Decorated tabs with sort-arrow and th-class computed properties
    get tabs() {
        return this._tabs.map(t => ({
            ...t,
            // th classes
            thCdtCode:        this._thClass(t, 'cdtCode'),
            thDescription:    this._thClass(t, 'description'),
            thFrequency:      this._thClass(t, 'frequencyDisplay'),
            // sort arrows
            arrowCdtCode:     this._arrow(t, 'cdtCode'),
            arrowDescription: this._arrow(t, 'description'),
            arrowFrequency:   this._arrow(t, 'frequencyDisplay')
        }));
    }

    _thClass(tab, field) {
        const base = 'dd-th dd-th--sortable';
        return tab.sortedBy === field ? `${base} dd-th--sorted` : base;
    }

    _arrow(tab, field) {
        if (tab.sortedBy !== field) return ARROW_NONE;
        return tab.sortDirection === 'asc' ? ARROW_ASC : ARROW_DESC;
    }

    // ─── Event handlers ───────────────────────────────────────────────────────

    handleTabSelect(event) {
        this.activeTabId = event.detail.value;
    }

    handleSearch(event) {
        const tabId     = event.target.dataset.tabId;
        const searchTerm = event.target.value;
        this._tabs = this._tabs.map(t => {
            if (t.id !== tabId) return t;
            const filtered = this._filterRows(t.allRows, searchTerm);
            const sorted   = this._sortRows(filtered, t.sortedBy, t.sortDirection);
            return {
                ...t,
                searchTerm,
                hasSearch:     searchTerm.length > 0,
                displayRows:   sorted,
                filteredCount: sorted.length,
                hasRows:       sorted.length > 0
            };
        });
    }

    handleClearSearch(event) {
        const tabId = event.currentTarget.dataset.tabId;
        this._tabs = this._tabs.map(t => {
            if (t.id !== tabId) return t;
            const sorted = this._sortRows(t.allRows, t.sortedBy, t.sortDirection);
            return {
                ...t,
                searchTerm:    '',
                hasSearch:     false,
                displayRows:   sorted,
                filteredCount: sorted.length,
                hasRows:       sorted.length > 0
            };
        });
    }

    handleSort(event) {
        const tabId = event.currentTarget.dataset.tabId;
        const field = event.currentTarget.dataset.field;
        this._tabs = this._tabs.map(t => {
            if (t.id !== tabId) return t;
            const newDir = t.sortedBy === field && t.sortDirection === 'asc' ? 'desc' : 'asc';
            return this._applySortToTab(t, field, newDir);
        });
    }

    // ─── Sort & filter helpers ────────────────────────────────────────────────

    _applySortToTab(tab, field, direction) {
        const filtered = this._filterRows(tab.allRows, tab.searchTerm);
        const sorted   = this._sortRows(filtered, field, direction);
        return {
            ...tab,
            sortedBy:      field,
            sortDirection: direction,
            displayRows:   sorted,
            filteredCount: sorted.length,
            hasRows:       sorted.length > 0
        };
    }

    _filterRows(rows, term) {
        if (!term) return rows;
        const lower = term.toLowerCase();
        return rows.filter(r =>
            r.cdtCode.toLowerCase().includes(lower) ||
            r.description.toLowerCase().includes(lower)
        );
    }

    _sortRows(rows, field, direction) {
        const mult = direction === 'asc' ? 1 : -1;
        return [...rows].sort((a, b) => {
            const av = a[field] || '';
            const bv = b[field] || '';
            return av < bv ? -mult : av > bv ? mult : 0;
        });
    }

    // ─── Format helpers ───────────────────────────────────────────────────────

    _formatFrequency(limit, period) {
        if (!limit && !period) return '—';
        if (limit && period) return `${limit}x / ${period}`;
        if (limit)           return `${limit}x`;
        return period;
    }

    _formatAgeRange(min, max) {
        if (min == null && max == null) return '—';
        if (min != null && max != null) return `${min}–${max}`;
        if (min != null) return `≥${min}`;
        return `≤${max}`;
    }

    _formatPct(val) {
        if (val == null) return '—';
        return `${val}%`;
    }

    _formatCopay(val) {
        if (val == null) return '—';
        return `$${Number(val).toFixed(2)}`;
    }

    // ─── Error helpers ────────────────────────────────────────────────────────

    _setError(msg) {
        this.isLoading    = false;
        this.hasError     = true;
        this.hasData      = false;
        this.errorMessage = msg;
    }

    _extractMessage(err) {
        if (!err) return 'Unknown error';
        if (typeof err === 'string') return err;
        if (err.body && err.body.message) return err.body.message;
        if (err.message) return err.message;
        return JSON.stringify(err);
    }
}
