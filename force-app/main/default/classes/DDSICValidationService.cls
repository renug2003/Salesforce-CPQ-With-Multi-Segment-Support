/**
 * @description Service class for SIC code eligibility and rate level resolution.
 *              Called by the rating engine and quote config service before any
 *              rate calculation or plan presentation.
 *
 *              Data flow:
 *                1. Query DD_SIC_Mapping__c via DDSICMappingSelector (database record)
 *                2. Fall back to DDConstants.INELIGIBLE_SIC_RANGES (in-memory) if no record found
 *
 * @author Enterprise Architecture Team
 * @date 2026-03
 */
public with sharing class DDSICValidationService {

    // ─────────────────────────────────────────────────────────────────────────
    // PUBLIC METHODS
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @description Validates that a SIC code is eligible for Delta Dental coverage.
     *              Throws DDValidationException immediately if ineligible so callers
     *              can surface the error to agents without proceeding to rating.
     *
     *              Ineligible categories include: dental offices (8021), dental labs
     *              (8071-8072), beauty/barber shops (7231-7241), employment agencies
     *              (7361-7363), membership organisations (8600-8699), private households
     *              (8811), farm labor (0761-0783), and others per NCCI guidelines.
     *
     * @param sicCode  4-digit SIC code string (e.g. '7372')
     * @throws DDValidationException if the SIC code is ineligible or blank/non-numeric
     */
    public static void validateEligibility(String sicCode) {
        if (String.isBlank(sicCode)) {
            throw new DDValidationException('SIC code is required for eligibility validation.');
        }

        Boolean eligible = DDSICMappingSelector.isEligible(sicCode);

        if (!eligible) {
            String industry = resolveIndustryDescription(sicCode);
            throw new DDValidationException(
                'SIC code ' + sicCode + ' (' + industry + ') is not eligible for Delta Dental coverage. '
                + 'This industry class is excluded under underwriting guidelines.'
            );
        }
    }

    /**
     * @description Returns the rate level for a SIC code: 'Level 1' or 'Level 2'.
     *              Level 2 industries (e.g., restaurants, auto dealerships, hotels)
     *              have higher claim utilisation and are priced at a surcharge.
     *              Throws DDValidationException if the code is ineligible or invalid.
     *
     * @param sicCode  4-digit SIC code string
     * @return 'Level 1' or 'Level 2'
     * @throws DDValidationException if ineligible or malformed
     */
    public static String getRateLevel(String sicCode) {
        // Validate first — ineligible codes must not receive a rate level
        validateEligibility(sicCode);

        String level = DDSICMappingSelector.getRateLevel(sicCode);

        // getRateLevel returns N/A for ineligible codes (belt-and-suspenders check)
        if (level == DDConstants.RATE_LEVEL_NA) {
            throw new DDValidationException(
                'SIC code ' + sicCode + ' returned N/A rate level — ineligible industry.'
            );
        }

        return level;
    }

    /**
     * @description Bulk validation — returns a map of sicCode → validation result message.
     *              An empty string value means the code is eligible.
     *              Used when validating census data with mixed SIC codes.
     *
     * @param sicCodes  List of SIC code strings to validate
     * @return Map<String, String> sicCode → '' (eligible) or error message (ineligible)
     */
    public static Map<String, String> validateEligibilityBulk(List<String> sicCodes) {
        Map<String, String> results = new Map<String, String>();
        if (sicCodes == null || sicCodes.isEmpty()) {
            return results;
        }

        Map<String, Boolean> eligibilityMap = DDSICMappingSelector.isEligibleBulk(sicCodes);

        for (String code : sicCodes) {
            Boolean eligible = eligibilityMap.get(code);
            if (eligible == null || !eligible) {
                results.put(code, 'SIC code ' + code + ' is ineligible for Delta Dental coverage.');
            } else {
                results.put(code, '');
            }
        }

        return results;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // PRIVATE HELPERS
    // ─────────────────────────────────────────────────────────────────────────

    private static String resolveIndustryDescription(String sicCode) {
        // Try to get description from the database record first
        DD_SIC_Mapping__c mapping = DDSICMappingSelector.getMapping(sicCode);
        if (mapping != null && !String.isBlank(mapping.Description__c)) {
            return mapping.Description__c;
        }

        // Fall back to DDConstants ranges
        try {
            Integer sicInt = Integer.valueOf(sicCode.trim());
            for (DDConstants.SICRange r : DDConstants.INELIGIBLE_SIC_RANGES) {
                if (r.contains(sicInt)) {
                    return r.industryDesc;
                }
            }
        } catch (Exception e) {
            // Non-numeric — description unavailable
        }

        return 'Unknown industry';
    }
}
