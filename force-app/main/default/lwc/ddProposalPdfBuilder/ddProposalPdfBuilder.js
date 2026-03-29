import { LightningElement, api } from 'lwc';
import { loadScript }           from 'lightning/platformResourceLoader';
import jspdfResource            from '@salesforce/resourceUrl/jspdf';
import getProposalPDFData       from '@salesforce/apex/DDQuoteBuilderController.getProposalPDFData';
import saveProposalPDF          from '@salesforce/apex/DDQuoteBuilderController.saveProposalPDF';

// ── Delta Dental official green brand colours ──────────────────────────────
const DD_GREEN        = [67,  176, 42];   // #43B02A  Core Green (primary brand)
const DD_GREEN_DARK   = [46,  125, 50];   // #2E7D32  Deep Green (hover / emphasis)
const DD_GREEN_MID    = [102, 187, 68];   // #66BB44  Balanced Green (secondary UI)
const DD_GREEN_SOFT   = [142, 217, 115];  // #8ED973  Soft Green (highlights)
const DD_GREEN_PALE   = [223, 245, 227];  // #DFF5E3  Pale Green (section backgrounds)
const DD_GREEN_MINT   = [243, 251, 244];  // #F3FBF4  Mint Tint (cards / containers)
const DD_NAVY         = [27,  94,  32];   // #1B5E20  Forest Green (strong contrast)
const DD_MID_BLUE     = [46,  125, 50];   // #2E7D32  (replaces mid-blue)
const DD_GRAY         = [109, 110, 113];  // #6D6E71
const DD_LIGHT_GRAY   = [232, 232, 232];  // #E8E8E8
const DD_OFF_WHITE    = [247, 247, 247];  // #F7F7F7
const DD_WHITE        = [255, 255, 255];
const DD_DARK         = [51,  51,  51];   // #333333

// ── Delta Dental official logo — SVG rendered to canvas then used via addImage ─
// The SVG faithfully reproduces the Delta Dental registered mark:
//   • Bold green "D" bracket shape (outer D minus inner D = bracket look)
//   • "DELTA DENTAL®" wordmark in the brand Core Green
const DD_LOGO_SVG = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 80">
  <g>
    <!-- Outer bold D shape -->
    <rect x="4" y="4" width="18" height="72" rx="2" fill="#43B02A"/>
    <path d="M22,4 Q74,4 74,40 Q74,76 22,76 Z" fill="#43B02A"/>
    <!-- Inner white cutout creates the bracket/tooth silhouette -->
    <path d="M22,20 Q56,20 56,40 Q56,60 22,60 Z" fill="white"/>
  </g>
  <!-- DELTA DENTAL wordmark -->
  <text x="84" y="50" font-family="Arial Black,Arial,Helvetica,sans-serif"
        font-size="34" font-weight="900" fill="#43B02A" letter-spacing="1">DELTA DENTAL</text>
  <text x="384" y="22" font-family="Arial,sans-serif" font-size="14" fill="#43B02A">®</text>
</svg>`;

/**
 * Converts the inline SVG logo string to a PNG data URL using an off-screen canvas.
 * Returns the full data URL (data:image/png;base64,...) ready for doc.addImage().
 */
function loadLogoDataUrl() {
    return new Promise((resolve) => {
        try {
            const encoded = btoa(unescape(encodeURIComponent(DD_LOGO_SVG)));
            const svgDataUrl = `data:image/svg+xml;base64,${encoded}`;
            const canvas = document.createElement('canvas');
            canvas.width = 400;
            canvas.height = 80;
            const ctx = canvas.getContext('2d');
            const img = new Image();
            img.onload = () => {
                ctx.drawImage(img, 0, 0, 400, 80);
                resolve(canvas.toDataURL('image/png'));
            };
            img.onerror = () => resolve(null);
            img.src = svgDataUrl;
        } catch (e) {
            resolve(null);
        }
    });
}

// ── Currency formatter ─────────────────────────────────────────────────────
function fmtCurrency(val) {
    if (val == null) return '$0.00';
    return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(val);
}

// ── Draw filled rectangle helper ──────────────────────────────────────────
function fillRect(doc, x, y, w, h, rgb) {
    doc.setFillColor(...rgb);
    doc.rect(x, y, w, h, 'F');
}

// ── Draw a table ──────────────────────────────────────────────────────────
// cols: [{label, width, align='left'}]
// rows: array of string arrays
// returns y after table
function drawTable(doc, x, y, cols, rows, opts = {}) {
    const rowH      = opts.rowH      || 7;
    const headerH   = opts.headerH   || 8;
    const fontSize  = opts.fontSize  || 8;
    const totalW    = cols.reduce((s, c) => s + c.width, 0);
    const pgH       = doc.internal.pageSize.getHeight();
    const margin    = opts.margin    || 14;

    // Header
    fillRect(doc, x, y, totalW, headerH, DD_NAVY);
    doc.setTextColor(...DD_WHITE);
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(fontSize);
    let cx = x;
    cols.forEach(col => {
        const align = col.align || 'left';
        const tx    = align === 'right' ? cx + col.width - 2 : cx + 2;
        doc.text(col.label, tx, y + headerH - 2.2, { align });
        cx += col.width;
    });
    y += headerH;

    // Rows
    doc.setFont('helvetica', 'normal');
    rows.forEach((row, ri) => {
        // Page break
        if (y + rowH > pgH - margin) {
            doc.addPage();
            y = margin;
        }
        fillRect(doc, x, y, totalW, rowH, ri % 2 === 0 ? DD_WHITE : DD_OFF_WHITE);
        doc.setTextColor(...DD_DARK);
        cx = x;
        row.forEach((cell, ci) => {
            const col   = cols[ci];
            const align = col.align || 'left';
            const tx    = align === 'right' ? cx + col.width - 2 : cx + 2;
            doc.text(String(cell ?? ''), tx, y + rowH - 2.2, { align });
            cx += col.width;
        });
        // Row border
        doc.setDrawColor(...DD_LIGHT_GRAY);
        doc.setLineWidth(0.2);
        doc.line(x, y + rowH, x + totalW, y + rowH);
        y += rowH;
    });

    // Outer border
    doc.setDrawColor(...DD_LIGHT_GRAY);
    doc.setLineWidth(0.3);
    doc.rect(x, y - rowH * rows.length - headerH, totalW, headerH + rowH * rows.length);

    return y;
}

// ── Section header ────────────────────────────────────────────────────────
function sectionHeader(doc, x, y, w, text) {
    fillRect(doc, x, y, w, 7, DD_GREEN);
    doc.setTextColor(...DD_WHITE);
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(8.5);
    doc.text(text.toUpperCase(), x + 3, y + 5);
    return y + 7;
}

// ── Info row (label: value) ────────────────────────────────────────────────
function infoRow(doc, x, y, label, value, w) {
    doc.setFont('helvetica', 'normal');
    doc.setFontSize(8);
    doc.setTextColor(...DD_GRAY);
    doc.text(label, x + 2, y + 4.5);
    doc.setTextColor(...DD_DARK);
    doc.setFont('helvetica', 'bold');
    doc.text(String(value ?? '—'), x + w * 0.42, y + 4.5);
    doc.setDrawColor(...DD_LIGHT_GRAY);
    doc.setLineWidth(0.2);
    doc.line(x, y + 6, x + w, y + 6);
    return y + 6;
}

// ── Highlight box ─────────────────────────────────────────────────────────
function highlightBox(doc, x, y, w, h, label, value) {
    doc.setDrawColor(...DD_GREEN);
    doc.setLineWidth(0.5);
    doc.setFillColor(...DD_GREEN_MINT);
    doc.roundedRect(x, y, w, h, 2, 2, 'FD');
    doc.setFont('helvetica', 'normal');
    doc.setFontSize(7);
    doc.setTextColor(...DD_GRAY);
    doc.text(label, x + w / 2, y + 4.5, { align: 'center' });
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(12);
    doc.setTextColor(...DD_NAVY);
    doc.text(value, x + w / 2, y + 12, { align: 'center' });
}

// ── Badge (green pill) ────────────────────────────────────────────────────
function badge(doc, x, y, text) {
    const tw = doc.getStringUnitWidth(text) * 7 / doc.internal.scaleFactor + 4;
    doc.setFillColor(...DD_GREEN);
    doc.roundedRect(x, y - 3.5, tw, 5, 1.5, 1.5, 'F');
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(7);
    doc.setTextColor(...DD_WHITE);
    doc.text(text, x + 2, y);
    return x + tw + 2;
}

// ── Main PDF builder ──────────────────────────────────────────────────────
function buildPDF(jsPDF, d, logoDataUrl) {
    const doc  = new jsPDF({ orientation: 'portrait', unit: 'mm', format: 'a4' });
    const pgW  = doc.internal.pageSize.getWidth();   // 210
    const pgH  = doc.internal.pageSize.getHeight();  // 297
    const mL   = 14, mR = 14, cW = pgW - mL - mR;  // content width = 182

    // ════════════════════════════════════════════════════════════════
    // HEADER BAND — Forest Green → Deep Green → Core Green gradient
    // ════════════════════════════════════════════════════════════════
    fillRect(doc, 0, 0, pgW, 38, DD_NAVY);          // Forest Green #1B5E20
    fillRect(doc, 0, 18, pgW, 12, DD_GREEN_DARK);   // Deep Green   #2E7D32
    fillRect(doc, 0, 26, pgW, 12, DD_GREEN);         // Core Green   #43B02A

    // Logo — real Delta Dental logo image (40mm wide × 8mm tall in the header)
    if (logoDataUrl) {
        // Place on white pill background so the green logo pops on the dark header
        doc.setFillColor(...DD_WHITE);
        doc.roundedRect(mL - 1, 5, 52, 12, 2, 2, 'F');
        doc.addImage(logoDataUrl, 'PNG', mL, 6, 50, 10);
    }

    // Organisation name
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(17);
    doc.setTextColor(...DD_WHITE);
    doc.text('Delta Dental of California', mL + 56, 16);

    // Tag line
    doc.setFont('helvetica', 'normal');
    doc.setFontSize(9);
    doc.setTextColor(...DD_GREEN_PALE);
    doc.text('Small Business Dental Insurance Proposal', mL + 56, 23);

    // Proposal reference line
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(8.5);
    doc.setTextColor(...DD_WHITE);
    const refText = `Proposal: ${d.proposalName}   |   Plan: ${d.planName}   |   Date: ${d.proposalDate}`;
    doc.text(refText, mL + 56, 31);

    // Horizontal rule below header
    doc.setDrawColor(...DD_GREEN);
    doc.setLineWidth(1.5);
    doc.line(0, 38, pgW, 38);

    let y = 46;

    // ════════════════════════════════════════════════════════════════
    // KEY HIGHLIGHTS ROW — 3 boxes
    // ════════════════════════════════════════════════════════════════
    const boxW = (cW - 8) / 3;
    highlightBox(doc, mL,              y, boxW, 18, 'Effective Date',   d.effectiveDate || '—');
    highlightBox(doc, mL + boxW + 4,   y, boxW, 18, 'Annual Maximum',   fmtCurrency(d.annualMax));
    highlightBox(doc, mL + boxW * 2 + 8, y, boxW, 18, 'Monthly Premium', fmtCurrency(d.totalPremium));
    y += 24;

    // ════════════════════════════════════════════════════════════════
    // TWO-COLUMN SECTION: Client Info + Plan Details
    // ════════════════════════════════════════════════════════════════
    const colW = (cW - 6) / 2;
    let yLeft = y, yRight = y;

    // ── Client Information ─────────────────────────────────────────
    yLeft = sectionHeader(doc, mL, yLeft, colW, 'Client Information');
    const clientRows = [
        ['Account',       d.accountName],
        ['Industry',      d.industry],
        ['Address',       [d.street, d.city, d.state, d.zip].filter(Boolean).join(', ')],
        ['Phone',         d.phone],
        ['Group Size',    d.groupSize ? `${d.groupSize} employees` : '—'],
        ['SIC Code',      d.sicCode],
        ['Segment',       d.segment],
        ['Quote Ref.',    d.quoteName]
    ];
    clientRows.forEach(([lbl, val]) => {
        yLeft = infoRow(doc, mL, yLeft, lbl, val, colW);
    });

    // ── Plan Details ───────────────────────────────────────────────
    const xRight = mL + colW + 6;
    yRight = sectionHeader(doc, xRight, yRight, colW, 'Plan Details');
    const planRows = [
        ['Plan Name',          d.planName],
        ['Network',            d.networkName],
        ['Annual Maximum',     fmtCurrency(d.annualMax)],
        ['Individual Deduct.', fmtCurrency(d.deductibleInd)],
        ['Family Deductible',  fmtCurrency(d.deductibleFam)],
        ['Employer Contrib.',  d.contributionPct != null ? `${d.contributionPct}%` : '—'],
        ['Rate Guarantee',     d.rateGuarantee   != null ? `${d.rateGuarantee} months` : '—']
    ];
    planRows.forEach(([lbl, val]) => {
        yRight = infoRow(doc, xRight, yRight, lbl, val, colW);
    });

    // Badges for optional riders
    let bx = xRight + 2;
    if (d.dnpWaiver) {
        yRight += 3;
        bx = badge(doc, bx, yRight, 'D&P Waiver');
    }
    if (d.waitingPeriodWaived) {
        if (!d.dnpWaiver) yRight += 3;
        bx = badge(doc, bx, yRight, 'Waiting Period Waived');
    }
    if (d.orthoType) {
        if (!d.dnpWaiver && !d.waitingPeriodWaived) yRight += 3;
        badge(doc, bx, yRight, `Ortho: ${d.orthoType} — ${fmtCurrency(d.orthoMax)}`);
    }
    if (d.dnpWaiver || d.waitingPeriodWaived || d.orthoType) yRight += 3;

    y = Math.max(yLeft, yRight) + 8;

    // ════════════════════════════════════════════════════════════════
    // COVERAGE SUMMARY TABLE
    // ════════════════════════════════════════════════════════════════
    if (d.coverage && d.coverage.length > 0) {
        if (y + 40 > pgH - 20) { doc.addPage(); y = 20; }
        y = sectionHeader(doc, mL, y, cW, 'Coverage Summary') + 2;
        const covCols = [
            { label: 'Coverage Category',    width: 80 },
            { label: 'PPO Network',          width: 34, align: 'right' },
            { label: 'Non-PPO Network',      width: 38, align: 'right' },
            { label: 'Deductible Applies',   width: 30, align: 'right' }
        ];
        const covRows = d.coverage.map(c => [
            c.name,
            c.ppoPct    != null ? `${c.ppoPct}%`    : 'N/A',
            c.nonPpoPct != null ? `${c.nonPpoPct}%` : 'N/A',
            c.deductibleApplies ? 'Yes' : 'No'
        ]);
        y = drawTable(doc, mL, y, covCols, covRows, { margin: 20 }) + 8;
    }

    // ════════════════════════════════════════════════════════════════
    // MONTHLY PREMIUM SUMMARY TABLE
    // ════════════════════════════════════════════════════════════════
    if (d.rates && d.rates.length > 0) {
        if (y + 50 > pgH - 20) { doc.addPage(); y = 20; }
        y = sectionHeader(doc, mL, y, cW, 'Monthly Premium Summary') + 2;
        const rateCols = [
            { label: 'Coverage Tier',     width: 36 },
            { label: 'Enrolled',          width: 22, align: 'right' },
            { label: 'Monthly Rate',      width: 34, align: 'right' },
            { label: 'Employer Share',    width: 36, align: 'right' },
            { label: 'Employee Share',    width: 28, align: 'right' },
            { label: 'Monthly Premium',   width: 26, align: 'right' }
        ];
        const rateRows2 = d.rates.map(r => [
            r.tier,
            r.enrolled,
            fmtCurrency(r.monthlyRate),
            fmtCurrency(r.employerShare),
            fmtCurrency(r.employeeShare),
            fmtCurrency(r.monthlyPremium)
        ]);
        y = drawTable(doc, mL, y, rateCols, rateRows2, { margin: 20 });

        // Total row
        const totalW = rateCols.reduce((s, c) => s + c.width, 0);
        fillRect(doc, mL, y, totalW, 8, DD_GREEN_PALE);
        doc.setDrawColor(...DD_GREEN);
        doc.setLineWidth(0.8);
        doc.line(mL, y, mL + totalW, y);
        doc.setFont('helvetica', 'bold');
        doc.setFontSize(8.5);
        doc.setTextColor(...DD_NAVY);
        doc.text('Total Monthly Premium', mL + 2, y + 5.5);
        doc.text(fmtCurrency(d.totalPremium), mL + totalW - 2, y + 5.5, { align: 'right' });
        y += 16;
    }

    // ════════════════════════════════════════════════════════════════
    // DISCLAIMER
    // ════════════════════════════════════════════════════════════════
    if (y + 22 > pgH - 20) { doc.addPage(); y = 20; }
    doc.setDrawColor(...DD_LIGHT_GRAY);
    doc.setLineWidth(0.3);
    doc.line(mL, y, mL + cW, y);
    y += 4;
    doc.setFont('helvetica', 'normal');
    doc.setFontSize(7);
    doc.setTextColor(...DD_GRAY);
    const disclaimer =
        'This proposal has been prepared based on the information provided and is subject to change. ' +
        'Coverage is subject to all terms, conditions, limitations, and exclusions of the plan contract. ' +
        'Rates are guaranteed for the rate guarantee period shown above from the effective date. ' +
        'Delta Dental of California is a not-for-profit dental service corporation and a member of the ' +
        'Delta Dental Plans Association. This proposal is valid for 30 days from the date of issue and ' +
        'is subject to final underwriting review.';
    const lines = doc.splitTextToSize(disclaimer, cW);
    doc.text(lines, mL, y);
    y += lines.length * 3.5 + 4;

    // ════════════════════════════════════════════════════════════════
    // FOOTER — every page
    // ════════════════════════════════════════════════════════════════
    const totalPages = doc.getNumberOfPages();
    for (let pg = 1; pg <= totalPages; pg++) {
        doc.setPage(pg);
        const fy = pgH - 8;
        fillRect(doc, 0, fy - 2, pgW, 10, DD_OFF_WHITE);
        doc.setDrawColor(...DD_LIGHT_GRAY);
        doc.setLineWidth(0.3);
        doc.line(0, fy - 2, pgW, fy - 2);
        doc.setFont('helvetica', 'normal');
        doc.setFontSize(7);
        doc.setTextColor(...DD_GRAY);
        doc.text('Delta Dental of California  •  deltadentalins.com  •  Confidential', mL, fy + 3);
        doc.text(`Page ${pg} of ${totalPages}`, pgW - mR, fy + 3, { align: 'right' });
    }

    return doc;
}

// ══════════════════════════════════════════════════════════════════
// LWC Component
// ══════════════════════════════════════════════════════════════════
export default class DdProposalPdfBuilder extends LightningElement {

    _jspdfLoaded = false;

    connectedCallback() {
        loadScript(this, jspdfResource)
            .then(() => { this._jspdfLoaded = true; })
            .catch(e => console.error('jsPDF load failed:', e));
    }

    /**
     * Public method called by the parent wizard.
     * proposalId — the DD_Proposal__c Id
     * Returns { contentDocumentId, downloadUrl }
     */
    @api
    async generateAndUpload(proposalId) {
        if (!this._jspdfLoaded) {
            // Wait up to 5s for the library to load
            await new Promise((resolve, reject) => {
                let tries = 0;
                const iv = setInterval(() => {
                    if (this._jspdfLoaded) { clearInterval(iv); resolve(); }
                    else if (++tries > 50) { clearInterval(iv); reject(new Error('jsPDF not loaded')); }
                }, 100);
            });
        }

        // Fetch proposal data from Apex and load logo in parallel
        const [data, logoDataUrl] = await Promise.all([
            getProposalPDFData({ proposalId }),
            loadLogoDataUrl()
        ]);

        // Build the PDF
        /* global jspdf */
        const { jsPDF } = window.jspdf;
        const doc = buildPDF(jsPDF, data, logoDataUrl);

        // Export as base64 string (no data-URI prefix)
        const base64 = doc.output('datauristring').split(',')[1];

        const safeName = `DeltaDental_${(data.planName || 'Proposal').replace(/[^a-zA-Z0-9]/g, '_')}_${data.proposalDate.replace(/\//g, '-')}.pdf`;

        // Upload to Salesforce and link to the proposal
        const cdId = await saveProposalPDF({ proposalId, base64Pdf: base64, fileName: safeName });

        return {
            contentDocumentId: cdId,
            downloadUrl: `/sfc/servlet.shepherd/document/download/${cdId}`
        };
    }
}
