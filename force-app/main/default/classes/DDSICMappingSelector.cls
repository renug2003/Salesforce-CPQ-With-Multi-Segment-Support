/**
 * @description Selector class for DD_SIC_Mapping__c.
 *              All SIC code eligibility and rate-level lookups go through this class.
 *
 *              SIC_Start__c and SIC_End__c are Text fields (zero-padded 4-digit strings).
 *              Bind variables are formatted as left-padded strings for SOQL comparisons.
 *              Falls back to DDConstants in-memory ranges when no database record exists
 *              (supports unit testing without seed data DML).
 * @author Enterprise Architecture Team
 * @date 2026-03
 */
public with sharing class DDSICMappingSelector {

    // ─────────────────────────────────────────────────────────────────────────
    // PUBLIC METHODS
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @description Returns the rate level string for a SIC code.
     *              Queries DD_SIC_Mapping__c first; falls back to DDConstants ranges.
     *              Cacheable — safe to call from LWC wire adapters.
     * @param sicCode  4-digit SIC code string (e.g. '7372')
     * @return 'Level 1', 'Level 2', or 'N/A' (ineligible)
     * @throws DDValidationException if sicCode is blank or non-numeric
     */
    @AuraEnabled(cacheable=true)
    public static String getRateLevel(String sicCode) {
        String sicStr = normaliseSIC(sicCode);

        List<DD_SIC_Mapping__c> mappings = [
            SELECT Rate_Level__c, Eligible__c
            FROM DD_SIC_Mapping__c
            WHERE SIC_Start__c <= :sicStr
              AND SIC_End__c   >= :sicStr
            ORDER BY SIC_Start__c DESC
            LIMIT 1
        ];

        if (!mappings.isEmpty()) {
            DD_SIC_Mapping__c m = mappings[0];
            if (m.Eligible__c == false) {
                return DDConstants.RATE_LEVEL_NA;
            }
            return String.isBlank(m.Rate_Level__c) ? DDConstants.RATE_LEVEL_1 : m.Rate_Level__c;
        }

        // Fallback: in-memory range evaluation from DDConstants
        return DDConstants.resolveRateLevel(Integer.valueOf(sicStr));
    }

    /**
     * @description Returns true when the SIC code is eligible for coverage.
     *              Ineligible industries include dental offices, labs, farm labor,
     *              employment agencies, membership organisations, private households.
     *              Cacheable — safe to call from LWC wire adapters.
     * @param sicCode  4-digit SIC code string
     * @return true if eligible, false if ineligible
     * @throws DDValidationException if sicCode is blank or non-numeric
     */
    @AuraEnabled(cacheable=true)
    public static Boolean isEligible(String sicCode) {
        String sicStr = normaliseSIC(sicCode);

        List<DD_SIC_Mapping__c> mappings = [
            SELECT Eligible__c
            FROM DD_SIC_Mapping__c
            WHERE SIC_Start__c <= :sicStr
              AND SIC_End__c   >= :sicStr
            ORDER BY SIC_Start__c DESC
            LIMIT 1
        ];

        if (!mappings.isEmpty()) {
            return mappings[0].Eligible__c == true;
        }

        // Fallback: check ineligible ranges in DDConstants
        Integer sicInt = Integer.valueOf(sicStr);
        for (DDConstants.SICRange r : DDConstants.INELIGIBLE_SIC_RANGES) {
            if (r.contains(sicInt)) {
                return false;
            }
        }
        return true;
    }

    /**
     * @description Returns the full DD_SIC_Mapping__c record matching a SIC code.
     *              Use when you need both eligibility and description in one call.
     * @param sicCode  4-digit SIC code string
     * @return The matching DD_SIC_Mapping__c, or null if no database record exists
     */
    public static DD_SIC_Mapping__c getMapping(String sicCode) {
        String sicStr = normaliseSIC(sicCode);

        List<DD_SIC_Mapping__c> mappings = [
            SELECT Id, SIC_Start__c, SIC_End__c, Rate_Level__c,
                   Description__c, Eligible__c
            FROM DD_SIC_Mapping__c
            WHERE SIC_Start__c <= :sicStr
              AND SIC_End__c   >= :sicStr
            ORDER BY SIC_Start__c DESC
            LIMIT 1
        ];

        return mappings.isEmpty() ? null : mappings[0];
    }

    /**
     * @description Bulk eligibility check — returns a map of sicCode → isEligible.
     *              Preferred over calling isEligible() in a loop to avoid hitting
     *              SOQL governor limits. Loads the full mapping table once.
     * @param sicCodes  List of 4-digit SIC code strings
     * @return Map<String, Boolean> — original sicCode → eligible flag
     */
    public static Map<String, Boolean> isEligibleBulk(List<String> sicCodes) {
        Map<String, Boolean> result = new Map<String, Boolean>();
        if (sicCodes == null || sicCodes.isEmpty()) {
            return result;
        }

        // Normalise input codes
        Map<String, String> originalToNormalised = new Map<String, String>();
        for (String code : sicCodes) {
            originalToNormalised.put(code, normaliseSIC(code));
        }

        // Load the full mapping table once — typically < 60 rows
        List<DD_SIC_Mapping__c> allMappings = [
            SELECT SIC_Start__c, SIC_End__c, Eligible__c
            FROM DD_SIC_Mapping__c
            ORDER BY SIC_Start__c ASC
        ];

        for (String code : sicCodes) {
            String sicStr   = originalToNormalised.get(code);
            Integer sicInt  = Integer.valueOf(sicStr);
            Boolean eligible = null;

            for (DD_SIC_Mapping__c m : allMappings) {
                if (m.SIC_Start__c <= sicStr && m.SIC_End__c >= sicStr) {
                    eligible = m.Eligible__c == true;
                    break;
                }
            }

            if (eligible == null) {
                // Fallback to DDConstants in-memory ranges
                eligible = true;
                for (DDConstants.SICRange r : DDConstants.INELIGIBLE_SIC_RANGES) {
                    if (r.contains(sicInt)) {
                        eligible = false;
                        break;
                    }
                }
            }

            result.put(code, eligible);
        }

        return result;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // PRIVATE HELPERS
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Validates and zero-pads a SIC code to 4 characters for Text field comparison.
     * '761'  → '0761'
     * '7372' → '7372'
     */
    private static String normaliseSIC(String sicCode) {
        if (String.isBlank(sicCode)) {
            throw new DDValidationException('SIC code cannot be blank');
        }
        String trimmed = sicCode.trim();
        if (!trimmed.isNumeric()) {
            throw new DDValidationException('SIC code must be numeric: ' + trimmed);
        }
        return trimmed.leftPad(4, '0');
    }
}
