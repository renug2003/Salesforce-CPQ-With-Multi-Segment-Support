import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getGroupInfo        from '@salesforce/apex/DDQuoteBuilderController.getGroupInfo';
import validateSIC         from '@salesforce/apex/DDQuoteBuilderController.validateSIC';
import getCensusData       from '@salesforce/apex/DDQuoteBuilderController.getCensusData';
import saveCensusEntries   from '@salesforce/apex/DDQuoteBuilderController.saveCensusEntries';
import getEligibleProducts from '@salesforce/apex/DDProductCatalogService.getEligibleProducts';
import initAndSelectPlan   from '@salesforce/apex/DDQuoteBuilderController.initAndSelectPlan';
import getProductBenefits  from '@salesforce/apex/DDQuoteBuilderController.getProductBenefits';
import updatePlanConfig    from '@salesforce/apex/DDQuoteBuilderController.updatePlanConfig';
import calculateRates      from '@salesforce/apex/DDQuoteBuilderController.calculateRates';
import submitQuote         from '@salesforce/apex/DDQuoteBuilderController.submitQuote';

// ── Constants ──────────────────────────────────────────────────────────────────

const TIER_OPTIONS = [
    { label: 'Employee Only (EE)',        value: 'EE' },
    { label: 'Employee + Spouse (ES)',     value: 'ES' },
    { label: 'Employee + Child(ren) (EC)', value: 'EC' },
    { label: 'Employee + Family (EF)',     value: 'EF' }
];

const GENDER_OPTIONS = [
    { label: 'Male',   value: 'M' },
    { label: 'Female', value: 'F' },
    { label: 'Other',  value: 'O' }
];

const CENSUS_COLUMNS = [
    { label: 'Employee',      fieldName: 'Employee_Name__c',   type: 'text' },
    { label: 'Tier',          fieldName: 'Enrollment_Tier__c', type: 'text',
      cellAttributes: { alignment: 'center' } },
    { label: 'Status',        fieldName: 'Status__c',          type: 'text' },
    { label: 'Date of Birth', fieldName: 'DOB__c',             type: 'date',
      typeAttributes: { year: 'numeric', month: 'short', day: '2-digit' } },
    { label: 'Hire Date',     fieldName: 'Hire_Date__c',       type: 'date',
      typeAttributes: { year: 'numeric', month: 'short', day: '2-digit' } },
    { label: 'Zip Code',      fieldName: 'Zip_Code__c',        type: 'text' }
];

// ── Component ──────────────────────────────────────────────────────────────────

export default class DdQuoteBuilder extends LightningElement {

    /** Opportunity ID — set by the record page or passed from ddNewQuoteAction */
    @api recordId;

    // ── Wizard State ──────────────────────────────────────────────────────────
    @track currentStep   = '1';
    @track isLoading     = false;
    @track errorMessage  = null;

    // ── Group / Account Info ──────────────────────────────────────────────────
    groupInfo  = null;
    sicResult  = null;

    // ── Census ────────────────────────────────────────────────────────────────
    @track censusData = {
        records: [], eeCount: 0, esCount: 0, ecCount: 0, efCount: 0, totalEnrolled: 0
    };
    @track censusMode  = 'upload';   // 'upload' | 'manual'
    @track manualRows  = [];
    nextRowId = 1;

    // ── Plan Selection ────────────────────────────────────────────────────────
    @track eligibleProducts = [];
    @track selectedPlanIds  = [];    // array of productId strings
    @track selectedPlans    = [];    // array of { productId, smId, product, sellingModel }

    // ── Plan Config ───────────────────────────────────────────────────────────
    @track planConfigs = [];         // PlanConfigWrapper extended with reactive _fields
    quoteId = null;

    // ── Benefits ──────────────────────────────────────────────────────────────
    @track benefitsCache = {};       // productId → PlanBenefitsWrapper

    // ── Rates ─────────────────────────────────────────────────────────────────
    @track rateResults = [];

    // ── Proposal ─────────────────────────────────────────────────────────────
    @track proposalCreated = false;

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    connectedCallback() {
        this.loadGroupInfo();
    }

    // ── Step Visibility ───────────────────────────────────────────────────────

    get isStep1() { return this.currentStep === '1'; }
    get isStep2() { return this.currentStep === '2'; }
    get isStep3() { return this.currentStep === '3'; }
    get isStep4() { return this.currentStep === '4'; }
    get isStep5() { return this.currentStep === '5'; }
    get isStep6() { return this.currentStep === '6'; }

    // ── Static Data ───────────────────────────────────────────────────────────

    get censusColumns() { return CENSUS_COLUMNS; }
    get tierOptions()   { return TIER_OPTIONS; }
    get genderOptions() { return GENDER_OPTIONS; }

    // ── Census Mode Helpers ───────────────────────────────────────────────────

    get isCensusModeUpload()  { return this.censusMode === 'upload'; }
    get isCensusModeManual()  { return this.censusMode === 'manual'; }

    get censusUploadBtnClass() {
        return this.censusMode === 'upload'
            ? 'dd-census-mode-btn dd-census-mode-btn--active'
            : 'dd-census-mode-btn';
    }

    get censusManualBtnClass() {
        return this.censusMode === 'manual'
            ? 'dd-census-mode-btn dd-census-mode-btn--active'
            : 'dd-census-mode-btn';
    }

    // ── Derived State Getters ─────────────────────────────────────────────────

    get accountId() {
        return this.groupInfo ? this.groupInfo.accountId : null;
    }

    get hasCensusRecords() {
        return this.censusData.records && this.censusData.records.length > 0;
    }

    get hasNoCensusRecords() {
        return !this.hasCensusRecords;
    }

    get progressSteps() {
        const steps = [
            { label: 'Census',       value: '1' },
            { label: 'Select Plans', value: '2' },
            { label: 'Compare',      value: '3' },
            { label: 'Configure',    value: '4' },
            { label: 'Rates',        value: '5' },
            { label: 'Proposal',     value: '6' }
        ];
        const current = parseInt(this.currentStep, 10);
        return steps.map((s, idx) => {
            const stepNum = idx + 1;
            const isCompleted = stepNum < current;
            const isActive    = stepNum === current;
            return {
                key:          s.value,
                value:        s.value,
                label:        s.label,
                isCompleted,
                isActive,
                stepClass:   'dd-prog-step' +
                             (isCompleted ? ' dd-prog-step--completed' : '') +
                             (isActive    ? ' dd-prog-step--active'    : ''),
                circleClass: 'dd-prog-circle' +
                             (isCompleted ? ' dd-prog-circle--completed' : '') +
                             (isActive    ? ' dd-prog-circle--active'    : '')
            };
        });
    }

    get hasEligibleProducts() {
        return this.eligibleProducts && this.eligibleProducts.length > 0;
    }

    get hasRateResults() {
        return this.rateResults && this.rateResults.length > 0;
    }

    get selectedCount() {
        return this.selectedPlanIds.length;
    }

    get isProceedDisabled() {
        return this.isLoading || this.selectedPlanIds.length === 0;
    }

    get sicRateLevel() {
        return this.sicResult ? this.sicResult.rateLevel : '—';
    }

    get proposalNotCreated() {
        return !this.proposalCreated;
    }

    /**
     * Groups eligible products by Plan_Family__c.
     * Adds isSelected and isDisabled flags, and a cardClass for CSS.
     */
    get groupedProducts() {
        if (!this.eligibleProducts || !this.eligibleProducts.length) return [];
        const map = {};
        this.eligibleProducts.forEach(ep => {
            const fam = ep.product.Plan_Family__c || 'Other';
            if (!map[fam]) map[fam] = { family: fam, plans: [] };
            const isSelected = this.selectedPlanIds.includes(ep.product.Id);
            const isDisabled = !isSelected && this.selectedPlanIds.length >= 3;
            let cardClass = 'dd-plan-card dd-plan-checkbox-card';
            if (isSelected) cardClass += ' dd-plan-checkbox-card--selected';
            if (isDisabled) cardClass += ' dd-plan-checkbox-card--disabled';
            map[fam].plans.push({ ...ep, isSelected, isDisabled, cardClass });
        });
        return Object.values(map);
    }

    // ── Navigation Getters ────────────────────────────────────────────────────

    get showBackButton() {
        return this.currentStep !== '1';
    }

    /**
     * Hide the generic Next button for:
     *  - Step 2: has its own "Compare & Configure" button
     *  - Step 3: has its own "Proceed to Configure" button
     *  - Step 6: has "Create Proposal" button
     */
    get showNextButton() {
        return this.currentStep !== '2'
            && this.currentStep !== '3'
            && this.currentStep !== '6';
    }

    get nextButtonLabel() {
        if (this.currentStep === '1') return 'Continue to Plans \u2192';
        if (this.currentStep === '4') return 'Save & Calculate Rates \u2192';
        if (this.currentStep === '5') return 'View Proposal \u2192';
        return 'Next \u2192';
    }

    get isNextDisabled() {
        if (this.isLoading) return true;
        if (this.currentStep === '1' && !this.hasCensusRecords) return true;
        return false;
    }

    // ── Step 1 — Load Group Info ──────────────────────────────────────────────

    async loadGroupInfo() {
        this.isLoading = true;
        this.clearError();
        try {
            this.groupInfo = await getGroupInfo({ opportunityId: this.recordId });
            if (this.groupInfo.sicCode) {
                this.sicResult = await validateSIC({ sicCode: this.groupInfo.sicCode });
            }
            // Pre-load census so tier tiles populate immediately
            if (this.groupInfo.accountId) {
                this.censusData = await getCensusData({ accountId: this.groupInfo.accountId });
            }
        } catch (e) {
            this.setError('Failed to load group info', e);
        } finally {
            this.isLoading = false;
        }
    }

    // ── Step 1 — Census Mode ──────────────────────────────────────────────────

    handleCensusMode(event) {
        this.censusMode = event.currentTarget.dataset.mode;
    }

    handleAddManualRow() {
        this.manualRows = [
            ...this.manualRows,
            {
                id:             this.nextRowId++,
                employeeName:   '',
                enrollmentTier: 'EE',
                gender:         '',
                dob:            null,
                hireDate:       null,
                zipCode:        ''
            }
        ];
    }

    handleRemoveRow(event) {
        const rowId = parseInt(event.currentTarget.dataset.rowId, 10);
        this.manualRows = this.manualRows.filter(r => r.id !== rowId);
    }

    handleManualFieldChange(event) {
        const rowId = parseInt(event.currentTarget.dataset.rowId, 10);
        const field = event.currentTarget.dataset.field;
        const value = event.detail.value;
        this.manualRows = this.manualRows.map(r => {
            if (r.id !== rowId) return r;
            return { ...r, [field]: value };
        });
    }

    async handleSaveCensus() {
        if (!this.accountId) return;
        const validRows = this.manualRows.filter(r => r.employeeName && r.enrollmentTier);
        if (validRows.length === 0) {
            this.setError('Validation', new Error('Please add at least one employee with a name and tier.'));
            return;
        }
        this.isLoading = true;
        this.clearError();
        try {
            const entries = validRows.map(r => ({
                employeeName:   r.employeeName,
                enrollmentTier: r.enrollmentTier,
                gender:         r.gender || null,
                dob:            r.dob    || null,
                hireDate:       r.hireDate || null,
                zipCode:        r.zipCode  || null
            }));
            await saveCensusEntries({ accountId: this.accountId, entriesJson: JSON.stringify(entries) });
            const saved = await getCensusData({ accountId: this.accountId });
            this.censusData = { ...saved, records: [...(saved.records || [])] };
            this.manualRows = [];
            this.censusMode = 'upload';
            this.toast('Census Saved', `${entries.length} employee(s) saved successfully.`, 'success');
        } catch (e) {
            this.setError('Failed to save census', e);
        } finally {
            this.isLoading = false;
        }
    }

    handleCensusUpload(event) {
        const count = event.detail.files ? event.detail.files.length : 1;
        this.toast('Census Uploaded', `${count} file(s) uploaded. Refreshing records…`, 'success');
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => this.reloadCensus(), 1500);
    }

    async reloadCensus() {
        if (!this.accountId) return;
        try {
            const result = await getCensusData({ accountId: this.accountId });
            this.censusData = { ...result, records: [...(result.records || [])] };
        } catch (e) {
            this.setError('Failed to refresh census', e);
        }
    }

    // ── Step 2 — Load Eligible Products ──────────────────────────────────────

    async loadEligibleProducts() {
        if (!this.groupInfo) return;
        this.isLoading = true;
        this.clearError();
        try {
            this.eligibleProducts = await getEligibleProducts({
                segment:         this.groupInfo.segment || 'Small Business',
                groupSize:       this.groupInfo.groupSize || 2,
                contributionPct: 50
            });
        } catch (e) {
            this.setError('Failed to load eligible plans', e);
        } finally {
            this.isLoading = false;
        }
    }

    // ── Step 2 — Plan Toggle ──────────────────────────────────────────────────

    handleTogglePlan(event) {
        const productId = event.currentTarget.dataset.productId;
        const smId      = event.currentTarget.dataset.smId;
        if (!productId || !smId) return;

        const alreadySelected = this.selectedPlanIds.includes(productId);

        if (alreadySelected) {
            // Deselect
            this.selectedPlanIds = this.selectedPlanIds.filter(id => id !== productId);
            this.selectedPlans   = this.selectedPlans.filter(sp => sp.productId !== productId);
        } else {
            // Select (guard: max 3)
            if (this.selectedPlanIds.length >= 3) return;

            // Find the eligible product entry
            let epFound = null;
            for (const ep of this.eligibleProducts) {
                if (ep.product.Id === productId) { epFound = ep; break; }
            }
            if (!epFound) return;

            this.selectedPlanIds = [...this.selectedPlanIds, productId];
            this.selectedPlans   = [
                ...this.selectedPlans,
                { productId, smId, product: epFound.product, sellingModel: epFound.sellingModel }
            ];
        }
    }

    // ── Step 2 → 3/4 — Proceed from Plan Selection ───────────────────────────

    async handleProceedToCompare() {
        if (this.selectedPlanIds.length === 0) {
            this.setError('Selection Required', new Error('Please select at least one plan.'));
            return;
        }
        this.clearError();
        await this.initSelectedPlans();
        if (this.selectedPlans.length === 1) {
            // Skip compare step when only one plan is chosen
            this.currentStep = '4';
        } else {
            this.currentStep = '3';
        }
    }

    // ── Step 3 → 4 ────────────────────────────────────────────────────────────

    handleProceedToConfigure() {
        this.currentStep = '4';
    }

    // ── Init Selected Plans (calls initAndSelectPlan for each) ────────────────

    async initSelectedPlans() {
        this.isLoading = true;
        this.clearError();
        try {
            const configPromises = this.selectedPlans.map(sp =>
                initAndSelectPlan({
                    opportunityId:  this.recordId,
                    productId:      sp.productId,
                    sellingModelId: sp.smId
                })
            );
            const configs = await Promise.all(configPromises);

            // All plans share the same quote — grab it from the first result
            if (configs.length > 0 && configs[0].quoteId) {
                this.quoteId = configs[0].quoteId;
            }

            this.planConfigs = configs.map(pc => this.extendPlanConfig(pc));
        } catch (e) {
            this.setError('Failed to initialize plan configuration', e);
        } finally {
            this.isLoading = false;
        }
    }

    /**
     * Extends a PlanConfigWrapper from Apex with reactive _field values
     * for binding to the configure-step inputs.
     */
    extendPlanConfig(pc) {
        return {
            ...pc,
            _annualMax:           pc.selectedAnnualMax   ? String(pc.selectedAnnualMax)  : null,
            _orthoEnabled:        !!pc.selectedOrthoType,
            _orthoType:           pc.selectedOrthoType   || null,
            _orthoMax:            pc.selectedOrthoMax    ? String(pc.selectedOrthoMax)   : null,
            _dnpWaiver:           pc.dnpWaiverSelected   || false,
            _contributionPct:     pc.contributionPct     != null ? pc.contributionPct : 50,
            _waitingPeriodWaived: pc.waitingPeriodWaived || false,
            _customDeductibleInd: pc.customDeductibleInd != null ? pc.customDeductibleInd : null,
            _customDeductibleFam: pc.customDeductibleFam != null ? pc.customDeductibleFam : null,
            isBenefitsOpen:       false,
            benefitsData:         null
        };
    }

    // ── Step 4 — Configure Handlers ───────────────────────────────────────────

    /**
     * Generic config field change handler.
     * Reads data-product-id and data-field from the event target,
     * then updates the matching planConfig's field.
     * Handles both toggle (checked) and other inputs (value).
     */
    handleConfigChange(event) {
        const productId = event.currentTarget.dataset.productId;
        const field     = event.currentTarget.dataset.field;
        if (!productId || !field) return;

        // Determine value: toggles use checked, all others use value
        const isToggle = event.target.type === 'toggle' || event.target.type === 'checkbox';
        const rawValue = isToggle ? event.target.checked : event.detail.value;

        this.planConfigs = this.planConfigs.map(pc => {
            if (pc.productId !== productId) return pc;
            return { ...pc, [field]: rawValue };
        });
    }

    /**
     * Specific handler for the Ortho toggle — uses event.detail.checked
     * and only updates _orthoEnabled (no data-field needed).
     */
    handleOrthoToggle(event) {
        const productId = event.currentTarget.dataset.productId;
        if (!productId) return;
        const checked = event.detail.checked;
        this.planConfigs = this.planConfigs.map(pc => {
            if (pc.productId !== productId) return pc;
            return { ...pc, _orthoEnabled: checked };
        });
    }

    // ── Step 4 — Benefits Toggle ──────────────────────────────────────────────

    async handleToggleBenefits(event) {
        const productId = event.currentTarget.dataset.productId;
        if (!productId) return;

        // Find the planConfig
        const pcIdx = this.planConfigs.findIndex(pc => pc.productId === productId);
        if (pcIdx === -1) return;

        const isCurrentlyOpen = this.planConfigs[pcIdx].isBenefitsOpen;

        if (isCurrentlyOpen) {
            // Close panel
            this.planConfigs = this.planConfigs.map((pc, idx) => {
                if (idx !== pcIdx) return pc;
                return { ...pc, isBenefitsOpen: false };
            });
            return;
        }

        // Open panel — load benefits if not cached
        if (!this.benefitsCache[productId]) {
            this.isLoading = true;
            try {
                const benefits = await getProductBenefits({ productId });
                this.benefitsCache = { ...this.benefitsCache, [productId]: benefits };
            } catch (e) {
                this.setError('Failed to load benefits', e);
                this.isLoading = false;
                return;
            } finally {
                this.isLoading = false;
            }
        }

        this.planConfigs = this.planConfigs.map((pc, idx) => {
            if (idx !== pcIdx) return pc;
            return {
                ...pc,
                isBenefitsOpen: true,
                benefitsData:   this.benefitsCache[productId]
            };
        });
    }

    // ── Step 4 → 5 — Save All Configs + Calculate Rates ──────────────────────

    async saveAllConfigsAndCalculate() {
        this.isLoading = true;
        this.clearError();
        try {
            const savePromises = this.planConfigs.map(pc =>
                updatePlanConfig({
                    configId:            pc.configId,
                    annualMax:           pc._annualMax ? parseFloat(pc._annualMax) : null,
                    orthoEnabled:        pc._orthoEnabled || false,
                    orthoType:           pc._orthoType   || null,
                    orthoMax:            pc._orthoMax    ? parseFloat(pc._orthoMax) : null,
                    dnpWaiver:           pc._dnpWaiver   || false,
                    contributionPct:     parseFloat(pc._contributionPct) || 50,
                    waitingPeriodWaived: pc._waitingPeriodWaived || false,
                    customDeductibleInd: pc._customDeductibleInd != null
                                            ? parseFloat(pc._customDeductibleInd) : null,
                    customDeductibleFam: pc._customDeductibleFam != null
                                            ? parseFloat(pc._customDeductibleFam) : null
                })
            );
            await Promise.all(savePromises);
            await this.handleCalculateRates();
        } catch (e) {
            this.setError('Failed to save configuration', e);
        } finally {
            this.isLoading = false;
        }
    }

    // ── Step 5 — Rate Calculation ─────────────────────────────────────────────

    async handleCalculateRates() {
        if (!this.quoteId) return;
        this.isLoading = true;
        this.clearError();
        try {
            const raw = await calculateRates({ quoteId: this.quoteId });
            this.rateResults = (raw || []).map(r => this.enrichRateResult(r));
        } catch (e) {
            this.setError('Rate calculation failed', e);
        } finally {
            this.isLoading = false;
        }
    }

    /** Adds pre-formatted currency strings and split-bar width styles to each result. */
    enrichRateResult(r) {
        const fmt = v => (v != null ? `$${Number(v).toFixed(2)}` : '$0.00');

        const totalPremium = r.totalMonthlyPremium || 0;
        const empShare     = r.employerShare || 0;
        const eeShare      = r.employeeShare || 0;

        const employerPct = totalPremium > 0
            ? Math.round((empShare / totalPremium) * 100) : 0;
        const employeePct = 100 - employerPct;

        return {
            ...r,
            totalMonthlyPremiumFormatted: fmt(totalPremium),
            employerShareFormatted:       fmt(empShare),
            employeeShareFormatted:       fmt(eeShare),
            employerPct,
            employeePct,
            employerPctFormatted:  `${employerPct}%`,
            employeePctFormatted:  `${employeePct}%`,
            employerBarStyle:      `width:${employerPct}%`,
            employeeBarStyle:      `width:${employeePct}%`,
            tierRates: (r.tierRates || []).map(tr => ({
                ...tr,
                monthlyRateFormatted:    fmt(tr.monthlyRate),
                monthlyPremiumFormatted: fmt(tr.monthlyPremium),
                employerShareFormatted:  fmt(tr.employerShare),
                employeeShareFormatted:  fmt(tr.employeeShare)
            }))
        };
    }

    // ── Step 6 — Create Proposal ──────────────────────────────────────────────

    async handleCreateProposal() {
        if (!this.quoteId) return;
        this.isLoading = true;
        this.clearError();
        try {
            await submitQuote({ quoteId: this.quoteId });
            this.proposalCreated = true;
            this.toast(
                'Proposal Created!',
                `The quote for ${this.groupInfo ? this.groupInfo.accountName : ''} ` +
                'has been submitted successfully.',
                'success'
            );
        } catch (e) {
            this.setError('Failed to create proposal', e);
        } finally {
            this.isLoading = false;
        }
    }

    // ── Navigation ────────────────────────────────────────────────────────────

    async handleNext() {
        const step = parseInt(this.currentStep, 10);
        this.clearError();

        if (step === 1) {
            // Validate census before moving on
            if (this.censusData.totalEnrolled === 0) {
                this.setError(
                    'Census Required',
                    new Error('Please upload or enter at least one employee before proceeding.')
                );
                return;
            }
            await this.loadEligibleProducts();
            if (!this.errorMessage) {
                this.currentStep = '2';
            }
        } else if (step === 4) {
            await this.saveAllConfigsAndCalculate();
            if (!this.errorMessage) {
                this.currentStep = '5';
            }
        } else if (step === 5) {
            this.currentStep = '6';
        }
    }

    handleBack() {
        const step = parseInt(this.currentStep, 10);
        this.clearError();

        if (step === 2) {
            this.currentStep = '1';
        } else if (step === 3) {
            this.currentStep = '2';
        } else if (step === 4) {
            // Go back to compare (if >1 plan selected) or plan selection
            this.currentStep = this.selectedPlans.length > 1 ? '3' : '2';
        } else if (step === 5) {
            this.currentStep = '4';
        } else if (step === 6) {
            this.currentStep = '5';
        }
    }

    // ── Utility ───────────────────────────────────────────────────────────────

    clearError() {
        this.errorMessage = null;
    }

    setError(prefix, error) {
        const msg = this.extractMessage(error);
        this.errorMessage = `${prefix}: ${msg}`;
        console.error('[ddQuoteBuilder]', prefix, error);
    }

    extractMessage(error) {
        if (!error) return 'Unknown error';
        if (error.body && error.body.message) return error.body.message;
        if (error.message) return error.message;
        return JSON.stringify(error);
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
