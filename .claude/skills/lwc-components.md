# Skill: Lightning Web Component Development

## When to Use
Use this skill when creating LWC components in `force-app/main/default/lwc/`.

## Delta Dental Insurance Website Color Palette

The design system matches deltadentalins.com/shopping — their quote flow page and main site.

### Primary Colors (extracted from deltadentalins.com)
```
--dd-blue-dark:    #003B71;   /* Dark navy — primary headers, top nav bar */
--dd-blue:         #00609A;   /* Mid blue — secondary headers, section backgrounds */
--dd-blue-light:   #0085CA;   /* Bright blue — links, active states, CTAs */
--dd-teal:         #00AEC7;   /* Teal accent — highlights, badges, icons */
```

### Secondary Colors
```
--dd-green:        #78BE20;   /* Bright green — success states, checkmarks, "Get Started" buttons */
--dd-green-dark:   #4C8C2B;   /* Darker green — hover state for green buttons */
--dd-orange:       #F47B20;   /* Orange — warning badges, attention callouts */
--dd-red:          #E03C31;   /* Red — error states, required field indicators */
```

### Neutral Colors
```
--dd-white:        #FFFFFF;   /* White — page background, card backgrounds */
--dd-off-white:    #F7F7F7;   /* Off-white — alternate section backgrounds */
--dd-gray-light:   #E8E8E8;   /* Light gray — borders, dividers, table stripes */
--dd-gray:         #6D6E71;   /* Mid gray — body text, secondary text */
--dd-gray-dark:    #333333;   /* Dark gray — primary body text */
--dd-black:        #1A1A1A;   /* Near-black — headings on white backgrounds */
```

### Gradient (Hero/Banner areas on deltadentalins.com)
```
background: linear-gradient(135deg, #003B71 0%, #00609A 50%, #0085CA 100%);
```

### Usage Rules (matching deltadentalins.com patterns)
- **Top navigation bar**: `--dd-blue-dark` (#003B71) solid background, white text
- **Hero/banner sections**: Dark blue gradient left-to-right (#003B71 → #0085CA)
- **Section headings**: `--dd-blue-dark` (#003B71) text on white background
- **Body text**: `--dd-gray-dark` (#333333)
- **Primary CTA buttons**: `--dd-green` (#78BE20) background, white text, rounded corners
- **Secondary CTA buttons**: `--dd-blue-light` (#0085CA) background or outlined
- **Links**: `--dd-blue-light` (#0085CA), underline on hover
- **Card headers**: `--dd-blue` (#00609A) background with white text
- **Table header rows**: `--dd-blue-dark` (#003B71) background, white text
- **Table alternating rows**: `--dd-off-white` (#F7F7F7) and white
- **Form inputs**: White background, `--dd-gray-light` (#E8E8E8) border, `--dd-blue-light` focus ring
- **Badges/tags**: `--dd-teal` (#00AEC7) background, white text
- **Progress indicators**: `--dd-green` (#78BE20) for completed, `--dd-gray-light` for pending
- **Footer**: `--dd-blue-dark` (#003B71) background, white text
- **Icons**: `--dd-teal` (#00AEC7) or `--dd-blue-light` (#0085CA)

## CSS Custom Properties Block (copy into every LWC)

```css
:host {
    /* === Delta Dental Brand (from deltadentalins.com) === */

    /* Primary Blues */
    --dd-blue-dark: #003B71;
    --dd-blue: #00609A;
    --dd-blue-light: #0085CA;
    --dd-teal: #00AEC7;

    /* Action Colors */
    --dd-green: #78BE20;
    --dd-green-dark: #4C8C2B;
    --dd-orange: #F47B20;
    --dd-red: #E03C31;

    /* Neutrals */
    --dd-white: #FFFFFF;
    --dd-off-white: #F7F7F7;
    --dd-gray-light: #E8E8E8;
    --dd-gray: #6D6E71;
    --dd-gray-dark: #333333;
    --dd-black: #1A1A1A;

    /* Gradient */
    --dd-gradient: linear-gradient(135deg, #003B71 0%, #00609A 50%, #0085CA 100%);

    /* Spacing */
    --dd-space-xs: 4px;
    --dd-space-sm: 8px;
    --dd-space-md: 16px;
    --dd-space-lg: 24px;
    --dd-space-xl: 32px;
    --dd-space-2xl: 48px;

    /* Border Radius (Delta Dental uses soft rounded corners) */
    --dd-radius-sm: 4px;
    --dd-radius: 8px;
    --dd-radius-lg: 12px;
    --dd-radius-pill: 24px;

    /* Shadows */
    --dd-shadow-sm: 0 1px 3px rgba(0,0,0,0.08);
    --dd-shadow: 0 2px 8px rgba(0,0,0,0.10);
    --dd-shadow-lg: 0 4px 16px rgba(0,0,0,0.14);

    /* Typography (Delta Dental uses a clean sans-serif stack) */
    --dd-font: 'Helvetica Neue', Helvetica, Arial, sans-serif;
    --dd-font-size-xs: 12px;
    --dd-font-size-sm: 14px;
    --dd-font-size-base: 16px;
    --dd-font-size-lg: 18px;
    --dd-font-size-xl: 24px;
    --dd-font-size-2xl: 32px;
    --dd-font-size-3xl: 40px;
}
```

## Component Templates

### Page Header (matching deltadentalins.com nav)
```html
<template>
    <div class="dd-header">
        <div class="dd-header__logo">
            <!-- Delta Dental logo area -->
            <span class="dd-header__title">Delta Dental Digital Insurance</span>
        </div>
        <div class="dd-header__nav">
            <slot name="navigation"></slot>
        </div>
    </div>
</template>
```
```css
.dd-header {
    background: var(--dd-blue-dark);
    color: var(--dd-white);
    padding: var(--dd-space-md) var(--dd-space-xl);
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-family: var(--dd-font);
}
.dd-header__title {
    font-size: var(--dd-font-size-lg);
    font-weight: 600;
    letter-spacing: 0.02em;
}
```

### Hero Banner (gradient like the quote page)
```css
.dd-hero {
    background: var(--dd-gradient);
    color: var(--dd-white);
    padding: var(--dd-space-2xl) var(--dd-space-xl);
    border-radius: 0 0 var(--dd-radius-lg) var(--dd-radius-lg);
}
.dd-hero__title {
    font-size: var(--dd-font-size-3xl);
    font-weight: 700;
    margin-bottom: var(--dd-space-sm);
}
.dd-hero__subtitle {
    font-size: var(--dd-font-size-lg);
    opacity: 0.9;
}
```

### Card Component (plan cards like deltadentalins.com comparison)
```html
<template>
    <div class="dd-plan-card">
        <div class="dd-plan-card__header">
            <h3 class="dd-plan-card__name">{planName}</h3>
            <lightning-badge label={planFamily} class="dd-badge-teal"></lightning-badge>
        </div>
        <div class="dd-plan-card__body">
            <slot></slot>
        </div>
        <div class="dd-plan-card__footer">
            <lightning-button
                label="Select Plan"
                variant="brand"
                onclick={handleSelect}
                class="dd-btn-green">
            </lightning-button>
        </div>
    </div>
</template>
```
```css
.dd-plan-card {
    background: var(--dd-white);
    border: 1px solid var(--dd-gray-light);
    border-radius: var(--dd-radius-lg);
    box-shadow: var(--dd-shadow);
    overflow: hidden;
    transition: box-shadow 0.2s ease, transform 0.2s ease;
    font-family: var(--dd-font);
}
.dd-plan-card:hover {
    box-shadow: var(--dd-shadow-lg);
    transform: translateY(-2px);
}
.dd-plan-card__header {
    background: var(--dd-blue);
    color: var(--dd-white);
    padding: var(--dd-space-lg);
    display: flex;
    justify-content: space-between;
    align-items: center;
}
.dd-plan-card__name {
    font-size: var(--dd-font-size-xl);
    font-weight: 700;
    margin: 0;
}
.dd-plan-card__body {
    padding: var(--dd-space-lg);
    color: var(--dd-gray-dark);
    font-size: var(--dd-font-size-base);
    line-height: 1.6;
}
.dd-plan-card__footer {
    padding: var(--dd-space-md) var(--dd-space-lg);
    border-top: 1px solid var(--dd-gray-light);
    background: var(--dd-off-white);
    text-align: center;
}
```

### Primary Button (green CTA like deltadentalins.com "Get Started")
```css
.dd-btn-green lightning-button {
    --sds-c-button-brand-color-background: var(--dd-green);
    --sds-c-button-brand-color-background-hover: var(--dd-green-dark);
    --sds-c-button-brand-color-border: var(--dd-green);
    --sds-c-button-brand-color-border-hover: var(--dd-green-dark);
    --sds-c-button-brand-text-color: var(--dd-white);
    --sds-c-button-border-radius: var(--dd-radius-pill);
}
```

### Table Styling (matching deltadentalins.com benefit comparison tables)
```css
.dd-table {
    width: 100%;
    border-collapse: collapse;
    font-family: var(--dd-font);
    font-size: var(--dd-font-size-sm);
}
.dd-table th {
    background: var(--dd-blue-dark);
    color: var(--dd-white);
    padding: var(--dd-space-sm) var(--dd-space-md);
    text-align: left;
    font-weight: 600;
    font-size: var(--dd-font-size-sm);
    text-transform: uppercase;
    letter-spacing: 0.04em;
}
.dd-table td {
    padding: var(--dd-space-sm) var(--dd-space-md);
    border-bottom: 1px solid var(--dd-gray-light);
    color: var(--dd-gray-dark);
}
.dd-table tr:nth-child(even) {
    background: var(--dd-off-white);
}
.dd-table tr:hover {
    background: #EBF5FB;
}
```

### Badge Styles
```css
.dd-badge-teal {
    --sds-c-badge-color-background: var(--dd-teal);
    --sds-c-badge-text-color: var(--dd-white);
}
.dd-badge-green {
    --sds-c-badge-color-background: var(--dd-green);
    --sds-c-badge-text-color: var(--dd-white);
}
.dd-badge-blue {
    --sds-c-badge-color-background: var(--dd-blue);
    --sds-c-badge-text-color: var(--dd-white);
}
```

### Form Inputs (matching deltadentalins.com/shopping quote form)
```css
.dd-form-group {
    margin-bottom: var(--dd-space-lg);
}
.dd-form-group label {
    display: block;
    font-size: var(--dd-font-size-sm);
    font-weight: 600;
    color: var(--dd-gray-dark);
    margin-bottom: var(--dd-space-xs);
}
.dd-form-group lightning-input {
    --sds-c-input-color-border: var(--dd-gray-light);
    --sds-c-input-color-border-focus: var(--dd-blue-light);
    --sds-c-input-shadow-focus: 0 0 0 3px rgba(0, 133, 202, 0.2);
    --sds-c-input-radius-border: var(--dd-radius);
}
```

### Progress Steps (matching quote wizard on deltadentalins.com)
```css
.dd-progress lightning-progress-indicator {
    --sds-c-progress-color-background: var(--dd-gray-light);
    --sds-c-progress-color-background-fill: var(--dd-green);
    --sds-c-progress-marker-color-background: var(--dd-green);
    --sds-c-progress-marker-color-background-incomplete: var(--dd-gray-light);
}
```

## Component Directory Structure
```
lwc/ddQuoteBuilder/
├── ddQuoteBuilder.html
├── ddQuoteBuilder.js
├── ddQuoteBuilder.css
├── ddQuoteBuilder.js-meta.xml
```

## Meta XML Template
```xml
<?xml version="1.0" encoding="UTF-8"?>
<LightningComponentBundle xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>62.0</apiVersion>
    <isExposed>true</isExposed>
    <masterLabel>DD Quote Builder</masterLabel>
    <description>Multi-step quote wizard for Delta Dental small business groups</description>
    <targets>
        <target>lightning__RecordPage</target>
        <target>lightning__AppPage</target>
        <target>lightning__HomePage</target>
        <target>lightning__Tab</target>
    </targets>
</LightningComponentBundle>
```

## Naming Conventions
- Component names: `dd{FeatureName}` (camelCase, prefix `dd`)
- CSS classes: `dd-{block}__{element}--{modifier}` (BEM-like with dd- prefix)
- All colors via CSS custom properties (never hardcoded hex values)
- Event names: `on{action}` (e.g., `onplanselect`, `onratechange`)
