import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getOppAndAccountDetails from '@salesforce/apex/DDQuoteBuilderController.getOppAndAccountDetails';
import saveCensusEntries       from '@salesforce/apex/DDQuoteBuilderController.saveCensusEntries';
import getEligibleProducts     from '@salesforce/apex/DDProductCatalogService.getEligibleProducts';
import initAndSelectPlan       from '@salesforce/apex/DDQuoteBuilderController.initAndSelectPlan';
import getProductBenefits      from '@salesforce/apex/DDQuoteBuilderController.getProductBenefits';
import updatePlanConfig        from '@salesforce/apex/DDQuoteBuilderController.updatePlanConfig';
import calculateRates          from '@salesforce/apex/DDQuoteBuilderController.calculateRates';
import submitQuote             from '@salesforce/apex/DDQuoteBuilderController.submitQuote';
import createProposals         from '@salesforce/apex/DDQuoteBuilderController.createProposals';
// v2 — uses jsPDF client-side generation (no generateProposalPDF)

// ── Step definitions ──────────────────────────────────────────────────────────
const STEPS = [
    { num: 1, label: 'Effective Date' },
    { num: 2, label: 'Census'         },
    { num: 3, label: 'Select Plans'   },
    { num: 4, label: 'Configure'      },
    { num: 5, label: 'Rate Summary'   },
    { num: 6, label: 'Proposals'      }
];

// Default census tiers
const DEFAULT_CENSUS_ROWS = () => [
    { tier: 'EE', label: 'Employee Only',       count: 0 },
    { tier: 'ES', label: 'Employee + Spouse',   count: 0 },
    { tier: 'EC', label: 'Employee + Children', count: 0 },
    { tier: 'EF', label: 'Employee + Family',   count: 0 }
];

const TIER_OPTIONS = [
    { label: 'Employee Only (EE)',       value: 'EE' },
    { label: 'Employee + Spouse (ES)',   value: 'ES' },
    { label: 'Employee + Children (EC)', value: 'EC' },
    { label: 'Employee + Family (EF)',   value: 'EF' }
];

export default class DdAccountQuoteCreator extends LightningElement {

    /** Opportunity Id injected by the parent overlay */
    @api recordId;

    // ── Global ────────────────────────────────────────────────────────────────
    @track currentStep  = 1;
    @track isLoading    = false;
    @track errorMessage = null;

    // ── Context panel (left column) ───────────────────────────────────────────
    @track contextData = null;

    // ── Step 1: Effective Date ─────────────────────────────────────────────────
    @track effectiveMonth = '';
    @track effectiveDate  = '';

    // ── Step 2: Census ────────────────────────────────────────────────────────
    @track censusMode    = 'quick';                // 'quick' | 'detailed'
    @track censusRows    = DEFAULT_CENSUS_ROWS();
    @track detailedEmps  = [];                     // detailed-mode rows
    _empIdSeq            = 0;

    get tierOptions()    { return TIER_OPTIONS; }

    get totalEnrolled() {
        if (this.censusMode === 'quick') {
            return this.censusRows.reduce((s, r) => s + (parseInt(r.count, 10) || 0), 0);
        }
        return this.detailedEmps.length;
    }
    get totalEnrolledLabel() { return `Total enrolled: ${this.totalEnrolled}`; }
    get isCensusQuick()    { return this.censusMode === 'quick'; }
    get isCensusDetailed() { return this.censusMode === 'detailed'; }
    get censusQuickBtnClass()    { return this.censusMode === 'quick'    ? 'census-mode-btn census-mode-btn--active' : 'census-mode-btn'; }
    get censusDetailedBtnClass() { return this.censusMode === 'detailed' ? 'census-mode-btn census-mode-btn--active' : 'census-mode-btn'; }
    get hasDetailedEmps()  { return this.detailedEmps.length > 0; }

    handleCensusModeQuick()    { this.censusMode = 'quick'; }
    handleCensusModeDetailed() { this.censusMode = 'detailed'; }

    handleCensusCountChange(event) {
        const tier = event.target.dataset.tier;
        const val  = Math.max(0, parseInt(event.target.value, 10) || 0);
        this.censusRows = this.censusRows.map(r =>
            r.tier === tier ? { ...r, count: val } : r
        );
    }

    handleAddEmployee() {
        this._empIdSeq++;
        this.detailedEmps = [...this.detailedEmps, {
            _id: this._empIdSeq, employeeName: '', enrollmentTier: 'EE',
            gender: '', dob: '', hireDate: '', zipCode: ''
        }];
    }

    handleRemoveEmployee(event) {
        const id = parseInt(event.currentTarget.dataset.empId, 10);
        this.detailedEmps = this.detailedEmps.filter(e => e._id !== id);
    }

    handleEmpFieldChange(event) {
        const id    = parseInt(event.target.dataset.empId, 10);
        const field = event.target.dataset.field;
        this.detailedEmps = this.detailedEmps.map(e =>
            e._id === id ? { ...e, [field]: event.target.value } : e
        );
    }

    async _saveCensus() {
        const accountId = this.contextData?.accountId;
        if (!accountId) return;

        let entries = [];
        if (this.censusMode === 'quick') {
            let n = 1;
            for (const row of this.censusRows) {
                const cnt = parseInt(row.count, 10) || 0;
                for (let i = 0; i < cnt; i++) {
                    entries.push({ employeeName: `Employee ${n++}`, enrollmentTier: row.tier,
                                   gender: null, dob: null, hireDate: null, zipCode: null });
                }
            }
        } else {
            entries = this.detailedEmps.map(e => ({
                employeeName:   e.employeeName || 'Employee',
                enrollmentTier: e.enrollmentTier,
                gender:         e.gender   || null,
                dob:            e.dob      || null,
                hireDate:       e.hireDate || null,
                zipCode:        e.zipCode  || null
            }));
        }
        await saveCensusEntries({ accountId, entriesJson: JSON.stringify(entries) });
    }

    // ── Step 3: Plan Selection ────────────────────────────────────────────────
    @track eligiblePlans  = [];
    @track _selectedIds   = [];
    @track _benefitsCache = {};

    _makePlanDisplay(ep) {
        return {
            productId:       ep.product.Id,
            productName:     ep.product.Product_Name__c,
            planFamily:      ep.product.Plan_Family__c || 'Other',
            networkName:     ep.product.Network_Fee_Basis__c,
            sellingModelId:  ep.sellingModel.Id,
            isSelected:      false,
            isDisabled:      false,
            benefitsLoaded:  false,
            benefitsLoading: false,
            coverageSpecs:   []
        };
    }

    async _loadPlans() {
        this.isLoading = true;
        try {
            // Apex requires groupSize >= 2 (DDConstants.MIN_GROUP_SIZE)
            const groupSz = Math.max(2, this.totalEnrolled || this.contextData?.groupSize || 2);
            const result = await getEligibleProducts({
                segment:         this.contextData?.segment || 'Small Business',
                groupSize:       groupSz,
                contributionPct: 50
            });
            this.eligiblePlans = (result || []).map(ep => this._makePlanDisplay(ep));
            this._selectedIds  = [];
            this.eligiblePlans.forEach(p => { this._loadPlanBenefits(p.productId); });
        } catch (e) {
            this.errorMessage = this._msg(e);
        } finally {
            this.isLoading = false;
        }
    }

    async _loadPlanBenefits(productId) {
        if (this._benefitsCache[productId]) {
            const specs = this._buildSpecs(this._benefitsCache[productId].coverageSpecs);
            this.eligiblePlans = this.eligiblePlans.map(p =>
                p.productId === productId
                    ? { ...p, benefitsLoaded: true, benefitsLoading: false, coverageSpecs: specs }
                    : p
            );
            return;
        }
        this.eligiblePlans = this.eligiblePlans.map(p =>
            p.productId === productId ? { ...p, benefitsLoading: true } : p
        );
        try {
            const data = await getProductBenefits({ productId });
            this._benefitsCache[productId] = data;
            const specs = this._buildSpecs(data.coverageSpecs || []);
            this.eligiblePlans = this.eligiblePlans.map(p =>
                p.productId === productId
                    ? { ...p, benefitsLoaded: true, benefitsLoading: false, coverageSpecs: specs }
                    : p
            );
        } catch {
            this.eligiblePlans = this.eligiblePlans.map(p =>
                p.productId === productId
                    ? { ...p, benefitsLoaded: true, benefitsLoading: false, coverageSpecs: [] }
                    : p
            );
        }
    }

    _buildSpecs(rawSpecs) {
        return (rawSpecs || []).map(cs => ({
            ...cs,
            isExpanded: false,
            chevron:    'utility:chevronright',
            hasBenefits: cs.benefits && cs.benefits.length > 0
        }));
    }

    get planFamilyGroups() {
        const map = {};
        (this.eligiblePlans || []).forEach(p => {
            const fam = p.planFamily;
            if (!map[fam]) map[fam] = { familyName: fam, plans: [] };
            map[fam].plans.push({
                ...p,
                cardClass:      'plan-card' +
                                (p.isSelected ? ' plan-card--selected' : '') +
                                (p.isDisabled ? ' plan-card--disabled'  : ''),
                showLoadHint:   !p.benefitsLoaded && !p.benefitsLoading,
                noCoverageData: p.benefitsLoaded && p.coverageSpecs.length === 0
            });
        });
        return Object.values(map);
    }

    get noPlansFound()      { return !this.isLoading && this.eligiblePlans.length === 0; }
    get selectedCount()     { return this._selectedIds.length; }
    get counterBadgeClass() {
        return 'selection-badge' + (this._selectedIds.length >= 3 ? ' selection-badge--full' : '');
    }

    handlePlanToggle(event) {
        const productId = event.target.dataset.id;
        const checked   = event.target.checked;
        if (checked && this._selectedIds.length >= 3) {
            event.target.checked = false; return;
        }
        const newSelected = checked
            ? [...this._selectedIds, productId]
            : this._selectedIds.filter(id => id !== productId);
        this._selectedIds  = newSelected;
        const maxReached   = newSelected.length >= 3;
        this.eligiblePlans = this.eligiblePlans.map(p => ({
            ...p,
            isSelected: newSelected.includes(p.productId),
            isDisabled: maxReached && !newSelected.includes(p.productId)
        }));
    }

    handleToggleCoverage(event) {
        const planId       = event.currentTarget.dataset.planId;
        const coverageName = event.currentTarget.dataset.coverage;
        this.eligiblePlans = this.eligiblePlans.map(p => {
            if (p.productId !== planId) return p;
            return {
                ...p,
                coverageSpecs: p.coverageSpecs.map(cs => {
                    if (cs.coverageName !== coverageName) return cs;
                    const expanded = !cs.isExpanded;
                    return { ...cs, isExpanded: expanded,
                             chevron: expanded ? 'utility:chevrondown' : 'utility:chevronright' };
                })
            };
        });
    }

    // ── Step 4: Configure Plans ───────────────────────────────────────────────
    @track planConfigs = [];
    @track quoteId     = null;

    async _initConfigs() {
        this.isLoading = true;
        try {
            // Sequential (not parallel) so the first call creates the Draft Quote
            // and each subsequent call finds and reuses it — avoiding duplicate quotes.
            const results = [];
            for (const productId of this._selectedIds) {
                const plan = this.eligiblePlans.find(p => p.productId === productId);
                // eslint-disable-next-line no-await-in-loop
                const cfg = await initAndSelectPlan({
                    opportunityId:  this.recordId,
                    productId,
                    sellingModelId: plan.sellingModelId
                });
                results.push(cfg);
            }
            this.quoteId    = results[0].quoteId;
            this.planConfigs = results.map(cfg => ({
                ...cfg,
                _annualMax:           cfg.selectedAnnualMax != null ? String(parseInt(cfg.selectedAnnualMax, 10)) : null,
                _orthoEnabled:        cfg.selectedOrthoType != null,
                _orthoType:           cfg.selectedOrthoType  || null,
                _orthoMax:            cfg.selectedOrthoMax   != null ? String(parseInt(cfg.selectedOrthoMax, 10)) : null,
                _dnpWaiver:           cfg.dnpWaiverSelected  || false,
                _contributionPct:     cfg.contributionPct    || 0,
                _waitingPeriodWaived: cfg.waitingPeriodWaived || false,
                _customDeductibleInd: cfg.customDeductibleInd,
                _customDeductibleFam: cfg.customDeductibleFam,
                _includeInProposal:   true
            }));
        } catch (e) {
            this.errorMessage = this._msg(e); throw e;
        } finally {
            this.isLoading = false;
        }
    }

    handleConfigChange(event) {
        const configId = event.target.dataset.configId;
        const field    = event.target.dataset.field;
        this.planConfigs = this.planConfigs.map(c =>
            c.configId === configId ? { ...c, [`_${field}`]: event.target.value } : c
        );
    }
    handleOrthoToggle(event) {
        const configId = event.target.dataset.configId;
        this.planConfigs = this.planConfigs.map(c =>
            c.configId === configId ? { ...c, _orthoEnabled: event.target.checked } : c
        );
    }
    handleDnpToggle(event) {
        const configId = event.target.dataset.configId;
        this.planConfigs = this.planConfigs.map(c =>
            c.configId === configId ? { ...c, _dnpWaiver: event.target.checked } : c
        );
    }
    handleWaitingPeriodToggle(event) {
        const configId = event.target.dataset.configId;
        this.planConfigs = this.planConfigs.map(c =>
            c.configId === configId ? { ...c, _waitingPeriodWaived: event.target.checked } : c
        );
    }

    async _saveConfigs() {
        this.isLoading = true;
        try {
            await Promise.all(this.planConfigs.map(c =>
                updatePlanConfig({
                    configId:            c.configId,
                    annualMax:           c._annualMax     ? parseFloat(c._annualMax)  : null,
                    orthoEnabled:        c._orthoEnabled,
                    orthoType:           c._orthoType,
                    orthoMax:            c._orthoMax      ? parseFloat(c._orthoMax)   : null,
                    dnpWaiver:           c._dnpWaiver,
                    contributionPct:     c._contributionPct,
                    waitingPeriodWaived: c._waitingPeriodWaived,
                    customDeductibleInd: c._customDeductibleInd,
                    customDeductibleFam: c._customDeductibleFam
                })
            ));
        } catch (e) {
            this.errorMessage = this._msg(e); throw e;
        } finally {
            this.isLoading = false;
        }
    }

    // ── Step 5: Rate Summary ──────────────────────────────────────────────────
    @track rateResults = [];

    async _loadRates() {
        this.isLoading = true;
        try {
            const raw = await calculateRates({ quoteId: this.quoteId });
            this.rateResults = (raw || []).map(r => {
                const total  = r.totalMonthlyPremium || 0;
                const empPct = total > 0 ? Math.round((r.employerShare / total) * 100) : 0;
                const eePct  = total > 0 ? Math.round((r.employeeShare / total) * 100) : 0;
                return {
                    ...r,
                    totalFmt:      this._fmt(total),
                    employerFmt:   this._fmt(r.employerShare),
                    employeeFmt:   this._fmt(r.employeeShare),
                    employerPct:   empPct,
                    employeePct:   eePct,
                    employerWidth: `width:${empPct}%`,
                    employeeWidth: `width:${eePct}%`,
                    tierRates: (r.tierRates || []).map(t => ({
                        ...t,
                        rateFmt:    this._fmt(t.monthlyRate),
                        premiumFmt: this._fmt(t.monthlyPremium)
                    }))
                };
            });
        } catch (e) {
            this.errorMessage = this._msg(e); throw e;
        } finally {
            this.isLoading = false;
        }
    }

    // ── Step 6: Proposals ─────────────────────────────────────────────────────
    @track proposalsCreated = false;
    @track createdProposals = [];

    handleProposalToggle(event) {
        const configId = event.target.dataset.configId;
        this.planConfigs = this.planConfigs.map(c =>
            c.configId === configId ? { ...c, _includeInProposal: event.target.checked } : c
        );
    }

    get proposalSelectionCount() {
        return this.planConfigs.filter(c => c._includeInProposal).length;
    }
    get isCreateDisabled() {
        return this.proposalSelectionCount === 0 || this.isLoading;
    }

    async handleCreateProposals() {
        const selected = this.planConfigs.filter(c => c._includeInProposal).map(c => c.configId);
        if (!selected.length) { this.errorMessage = 'Please select at least one plan.'; return; }

        this.isLoading = true; this.errorMessage = null;
        try {
            await submitQuote({ quoteId: this.quoteId });
            const proposalIds = await createProposals({
                quoteId: this.quoteId, planConfigIds: selected, effectiveDateStr: this.effectiveDate
            });

            // Use the jsPDF-based builder for each proposal
            const pdfBuilder = this.template.querySelector('c-dd-proposal-pdf-builder');
            const results = [];
            for (const pid of proposalIds) {
                // eslint-disable-next-line no-await-in-loop
                const r = await pdfBuilder.generateAndUpload(pid);
                results.push(r);
            }

            this.createdProposals = proposalIds.map((pid, i) => {
                const plan = this.planConfigs.find(c => c._includeInProposal &&
                    selected[i] === c.configId);
                return {
                    id:      pid,
                    name:    (plan?.productName) || `Proposal ${i + 1}`,
                    propUrl: `/lightning/r/DD_Proposal__c/${pid}/view`,
                    pdfUrl:  results[i]?.downloadUrl || null
                };
            });
            this.proposalsCreated = true;
            this._toast('Proposals Created', `${proposalIds.length} proposal(s) created.`, 'success');
        } catch (e) {
            this.errorMessage = this._msg(e);
        } finally {
            this.isLoading = false;
        }
    }

    // ── Context panel ─────────────────────────────────────────────────────────
    connectedCallback() { this._loadContext(); }

    async _loadContext() {
        if (!this.recordId) return;
        this.isLoading = true;
        try {
            this.contextData = await getOppAndAccountDetails({ oppId: this.recordId });
        } catch (e) {
            this.errorMessage = this._msg(e);
        } finally {
            this.isLoading = false;
        }
    }

    get ctxAccountName()  { return this.contextData?.accountName   ?? '—'; }
    get ctxIndustry()     { return this.contextData?.industry      ?? '—'; }
    get ctxPhone()        { return this.contextData?.phone         ?? '—'; }
    get ctxGroupSize()    { return this.contextData?.groupSize     ?? '—'; }
    get ctxSicCode()      { return this.contextData?.sicCode       ?? '—'; }
    get ctxSegment()      { return this.contextData?.segment       ?? '—'; }
    get ctxOppName()      { return this.contextData?.oppName       ?? '—'; }
    get ctxQuoteStatus()  { return this.contextData?.quoteStatus   ?? 'Draft'; }
    get ctxAddress() {
        if (!this.contextData) return '—';
        return [this.contextData.billingStreet, this.contextData.billingCity,
                this.contextData.billingState,  this.contextData.billingPostalCode]
            .filter(Boolean).join(', ') || '—';
    }
    get ctxAccountUrl() {
        return this.contextData?.accountId
            ? `/lightning/r/Account/${this.contextData.accountId}/view` : '#';
    }
    get ctxOppUrl() {
        return this.recordId ? `/lightning/r/Opportunity/${this.recordId}/view` : '#';
    }
    get ctxSelectedPlans() {
        return this.eligiblePlans.filter(p => this._selectedIds.includes(p.productId));
    }
    get ctxHasSelected() { return this._selectedIds.length > 0; }

    // ── Step indicator ────────────────────────────────────────────────────────
    get steps() {
        return STEPS.map(s => ({
            ...s,
            cssClass: 'step-item' +
                      (s.num === this.currentStep ? ' step-item--active'    : '') +
                      (s.num  < this.currentStep  ? ' step-item--completed' : '')
        }));
    }

    get isStep1() { return this.currentStep === 1; }
    get isStep2() { return this.currentStep === 2; }
    get isStep3() { return this.currentStep === 3; }
    get isStep4() { return this.currentStep === 4; }
    get isStep5() { return this.currentStep === 5; }
    get isStep6() { return this.currentStep === 6; }

    // ── Effective Date ────────────────────────────────────────────────────────
    get minEffectiveMonth() {
        const d = new Date();
        d.setMonth(d.getMonth() + 1);
        return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
    }
    get effectiveDateDisplay() {
        if (!this.effectiveDate) return null;
        try {
            return new Date(this.effectiveDate + 'T12:00:00')
                .toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' });
        } catch { return this.effectiveDate; }
    }
    handleEffectiveDateChange(event) {
        this.effectiveMonth = event.target.value;
        this.effectiveDate  = this.effectiveMonth ? this.effectiveMonth + '-01' : '';
    }

    // ── Navigation ────────────────────────────────────────────────────────────
    get showBack() { return this.currentStep > 1 && !this.proposalsCreated; }
    get showNext() { return !this.proposalsCreated; }
    get nextLabel() {
        return { 1: 'Enter Census →', 2: 'Select Plans →', 3: 'Configure Plans →',
                 4: 'Calculate Rates →', 5: 'Review Proposals →', 6: 'Create Proposals'
               }[this.currentStep] || 'Next';
    }
    get isNextDisabled() {
        if (this.isLoading) return true;
        if (this.currentStep === 1) return !this.effectiveDate;
        if (this.currentStep === 2) return this.totalEnrolled < 2;
        if (this.currentStep === 3) return this._selectedIds.length === 0;
        if (this.currentStep === 6) return this.isCreateDisabled;
        return false;
    }

    async handleNext() {
        this.errorMessage = null;
        if (this.currentStep === 1) {
            this.currentStep = 2;

        } else if (this.currentStep === 2) {
            // Save census (non-blocking — a failure here should not prevent plan loading)
            try {
                this.isLoading = true;
                await this._saveCensus();
            } catch (e) {
                // Census save failed — log but continue to plan selection
                console.warn('Census save failed (non-blocking):', this._msg(e));
            } finally {
                this.isLoading = false;
            }
            // Load eligible plans (this sets errorMessage on failure)
            await this._loadPlans();
            if (!this.errorMessage) this.currentStep = 3;

        } else if (this.currentStep === 3) {
            try {
                await this._initConfigs();
                if (!this.errorMessage) this.currentStep = 4;
            } catch (e) {
                this.errorMessage = this._msg(e);
            }

        } else if (this.currentStep === 4) {
            try {
                await this._saveConfigs();
                await this._loadRates();
                if (!this.errorMessage) this.currentStep = 5;
            } catch (e) {
                this.errorMessage = this._msg(e);
            }

        } else if (this.currentStep === 5) {
            this.currentStep = 6;

        } else if (this.currentStep === 6) {
            await this.handleCreateProposals();
        }
    }

    handleBack() {
        this.errorMessage = null;
        if (this.currentStep > 1) this.currentStep--;
    }

    // ── Save / Save & Close ────────────────────────────────────────────────────
    async _persistCurrentState() {
        // Save census if we're on step 2+
        if (this.currentStep >= 2 && this.contextData?.accountId) {
            try { await this._saveCensus(); } catch (e) { /* non-blocking */ }
        }
        // Save plan configs if we're on step 4+
        if (this.currentStep >= 4 && this.planConfigs.length > 0) {
            await this._saveConfigs();
        }
    }

    async handleSave() {
        this.errorMessage = null;
        this.isLoading = true;
        try {
            await this._persistCurrentState();
            this._toast('Saved', 'Quote progress saved successfully.', 'success');
        } catch (e) {
            this.errorMessage = this._msg(e);
        } finally {
            this.isLoading = false;
        }
    }

    async handleSaveAndClose() {
        this.errorMessage = null;
        this.isLoading = true;
        try {
            await this._persistCurrentState();
            this._toast('Saved', 'Quote saved. Closing wizard.', 'success');
            this.dispatchEvent(new CustomEvent('close'));
        } catch (e) {
            this.errorMessage = this._msg(e);
        } finally {
            this.isLoading = false;
        }
    }

    get showSaveButtons() {
        // Show save buttons from step 2 onward, but not on the proposals success screen
        return this.currentStep >= 2 && !this.proposalsCreated;
    }

    handleDismissError() { this.errorMessage = null; }

    handleDone() { this.dispatchEvent(new CustomEvent('close')); }

    // ── Utilities ─────────────────────────────────────────────────────────────
    _fmt(val) {
        if (val == null) return '$0.00';
        return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(val);
    }
    _msg(e) { return e?.body?.message || e?.message || 'An unexpected error occurred.'; }
    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
