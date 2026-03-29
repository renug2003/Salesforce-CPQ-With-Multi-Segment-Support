/**
 * @description Constants for the Delta Dental Digital Insurance CPQ platform.
 *              All picklist values, SIC code maps, and business thresholds live here.
 *              Never hardcode these values elsewhere — always reference DDConstants.
 * @author Enterprise Architecture Team
 * @date 2026-03
 */
public with sharing class DDConstants {

    // ─────────────────────────────────────────────────────────────────
    // PLAN FAMILIES  (DD_Product__c.Plan_Family__c)
    // ─────────────────────────────────────────────────────────────────
    public static final String PLAN_FAMILY_PPO_DELUXE    = 'PPO Deluxe';
    public static final String PLAN_FAMILY_PPO_ADVANTAGE = 'PPO Advantage';
    public static final String PLAN_FAMILY_PPO_CORE      = 'PPO Core';
    public static final String PLAN_FAMILY_DHMO          = 'DeltaCare USA';
    public static final String PLAN_FAMILY_DUAL_CHOICE   = 'Dual Choice';
    public static final String PLAN_FAMILY_CORE_BUYUP    = 'Core Buy-Up';
    public static final String PLAN_FAMILY_PEDIATRIC     = 'Pediatric';

    // ─────────────────────────────────────────────────────────────────
    // NETWORK FEE BASIS  (DD_Product__c.Network_Fee_Basis__c)
    // ─────────────────────────────────────────────────────────────────
    public static final String NETWORK_PPO              = 'PPO';
    public static final String NETWORK_PPO_PLUS_PREMIER = 'PPO Plus Premier';
    public static final String NETWORK_DELTACARE        = 'DeltaCare USA';

    // ─────────────────────────────────────────────────────────────────
    // MARKET SEGMENTS  (DD_Selling_Model__c.Segment__c)
    // ─────────────────────────────────────────────────────────────────
    public static final String SEGMENT_SMALL_BUSINESS = 'Small Business';
    public static final String SEGMENT_INDIVIDUAL     = 'Individual';
    public static final String SEGMENT_MID_MARKET     = 'Mid-Market';
    public static final String SEGMENT_LARGE_GROUP    = 'Large Group';

    // ─────────────────────────────────────────────────────────────────
    // RATE TIERS  (DD_Quote_Rate_Result__c.Tier__c, DD_Census__c.Enrollment_Tier__c)
    // ─────────────────────────────────────────────────────────────────
    public static final String TIER_EE = 'EE';   // Employee Only
    public static final String TIER_ES = 'ES';   // Employee + Spouse
    public static final String TIER_EC = 'EC';   // Employee + Child(ren)
    public static final String TIER_EF = 'EF';   // Employee + Family

    public static final List<String> ALL_TIERS = new List<String>{ TIER_EE, TIER_ES, TIER_EC, TIER_EF };

    // ─────────────────────────────────────────────────────────────────
    // COVERAGE CATEGORIES  (DD_Coverage_Spec__c.Coverage_Code__c)
    // ─────────────────────────────────────────────────────────────────
    public static final String CAT_DNP        = 'Diagnostic & Preventive';
    public static final String CAT_BASIC      = 'Basic';
    public static final String CAT_ENDO_PERIO = 'Endodontics Periodontics Oral Surgery';
    public static final String CAT_MAJOR      = 'Major';
    public static final String CAT_ORTHO      = 'Orthodontia';

    public static final String CODE_DNP        = 'DNP';
    public static final String CODE_BASIC      = 'BASIC';
    public static final String CODE_ENDO_PERIO = 'ENDO';
    public static final String CODE_MAJOR      = 'MAJOR';
    public static final String CODE_ORTHO      = 'ORTHO';

    // ─────────────────────────────────────────────────────────────────
    // RATE LEVELS  (DD_SIC_Mapping__c.Rate_Level__c)
    // ─────────────────────────────────────────────────────────────────
    public static final String RATE_LEVEL_1  = 'Level 1';
    public static final String RATE_LEVEL_2  = 'Level 2';
    public static final String RATE_LEVEL_NA = 'N/A';      // ineligible SIC code

    // ─────────────────────────────────────────────────────────────────
    // FREQUENCY PERIODS  (DD_Benefit_Spec__c.Frequency_Period__c)
    // ─────────────────────────────────────────────────────────────────
    public static final String FREQ_CALENDAR_YEAR = 'Calendar Year';
    public static final String FREQ_BENEFIT_YEAR  = 'Benefit Year';
    public static final String FREQ_LIFETIME      = 'Lifetime';
    public static final String FREQ_ROLLING_12    = 'Rolling 12 Months';

    // ─────────────────────────────────────────────────────────────────
    // POLICY / ENROLLMENT STATUS
    // ─────────────────────────────────────────────────────────────────
    public static final String STATUS_ACTIVE     = 'Active';
    public static final String STATUS_INACTIVE   = 'Inactive';
    public static final String STATUS_TERMINATED = 'Terminated';
    public static final String STATUS_PENDING    = 'Pending';
    public static final String STATUS_RECEIVED   = 'Received';

    // ─────────────────────────────────────────────────────────────────
    // BUSINESS THRESHOLDS
    // ─────────────────────────────────────────────────────────────────
    public static final Integer MIN_GROUP_SIZE               = 2;
    public static final Integer MIN_ENROLLED_DUAL_CHOICE     = 5;
    public static final Integer MIN_ENROLLED_ORTHO           = 5;
    public static final Integer MIN_ENROLLED_ADULT_ORTHO_VOL = 50;
    public static final Decimal MIN_CONTRIBUTION_CORE_BUYUP  = 50.0;
    public static final Integer VOLUNTARY_WAIT_MONTHS        = 12;
    public static final Integer DEPENDENT_AGE_LIMIT          = 26;
    public static final Decimal COBRA_RATE_MULTIPLIER        = 1.02;
    public static final Integer RATE_GUARANTEE_MONTHS        = 12;
    public static final Integer MAX_SB_GROUP_SIZE            = 99;
    public static final Integer MAX_MM_GROUP_SIZE            = 999;

    // ─────────────────────────────────────────────────────────────────
    // SIC CODE RANGE HELPER
    // Used by DDSICMappingSelector for in-memory lookups and validation.
    // SIC codes are stored as zero-padded Text in the org; the integer
    // representation is used here for range comparisons.
    // ─────────────────────────────────────────────────────────────────
    public class SICRange {
        public Integer startCode;
        public Integer endCode;
        public String  rateLevel;
        public String  industryDesc;  // 'desc' is a reserved Apex keyword — use industryDesc

        public SICRange(Integer s, Integer e, String level, String industry) {
            this.startCode   = s;
            this.endCode     = e;
            this.rateLevel   = level;
            this.industryDesc = industry;
        }

        public Boolean contains(Integer sic) {
            return sic >= startCode && sic <= endCode;
        }
    }

    /**
     * Ineligible SIC ranges — sourced from data/rates/rate_level_mapping.csv
     * where Eligible__c = false.
     */
    public static final List<SICRange> INELIGIBLE_SIC_RANGES = new List<SICRange>{
        new SICRange(761,  783,  RATE_LEVEL_NA, 'Seasonal Employees - Farm Labor'),
        new SICRange(7231, 7241, RATE_LEVEL_NA, 'Beauty and Barber Shops'),
        new SICRange(7361, 7363, RATE_LEVEL_NA, 'Employment Agencies'),
        new SICRange(7389, 7389, RATE_LEVEL_NA, 'Misc Business Services NEC'),
        new SICRange(8021, 8021, RATE_LEVEL_NA, 'Dental Offices'),
        new SICRange(8071, 8072, RATE_LEVEL_NA, 'Dental Labs and Medical Labs'),
        new SICRange(8600, 8699, RATE_LEVEL_NA, 'Membership Organizations'),
        new SICRange(8811, 8811, RATE_LEVEL_NA, 'Private Households'),
        new SICRange(8999, 8999, RATE_LEVEL_NA, 'Misc Services NEC'),
        new SICRange(9721, 9721, RATE_LEVEL_NA, 'International Affairs')
    };

    /**
     * Level 2 SIC ranges — sourced from data/rates/rate_level_mapping.csv
     * where Rate_Level__c = 'Level 2'. All other eligible codes are Level 1.
     */
    public static final List<SICRange> LEVEL2_SIC_RANGES = new List<SICRange>{
        new SICRange(3911, 3915, RATE_LEVEL_2, 'Jewelry Manufacturing'),
        new SICRange(5511, 5599, RATE_LEVEL_2, 'Auto Dealerships'),
        new SICRange(5800, 5899, RATE_LEVEL_2, 'Restaurants'),
        new SICRange(6300, 6499, RATE_LEVEL_2, 'Insurance Carriers Brokers'),
        new SICRange(6500, 6799, RATE_LEVEL_2, 'Real Estate'),
        new SICRange(7000, 7099, RATE_LEVEL_2, 'Hotels and Lodging'),
        new SICRange(7221, 7221, RATE_LEVEL_2, 'Photographic Studios Portrait'),
        new SICRange(7291, 7299, RATE_LEVEL_2, 'Services Tax Return Misc'),
        new SICRange(7319, 7319, RATE_LEVEL_2, 'Services NEC'),
        new SICRange(7631, 7631, RATE_LEVEL_2, 'Watch Clock Jewelry Repair'),
        new SICRange(7800, 7999, RATE_LEVEL_2, 'Amusement Recreation Entertainment'),
        new SICRange(8000, 8059, RATE_LEVEL_2, 'Medical Groups'),
        new SICRange(8082, 8099, RATE_LEVEL_2, 'Medical Groups Other'),
        new SICRange(8100, 8199, RATE_LEVEL_2, 'Legal Services'),
        new SICRange(9999, 9999, RATE_LEVEL_2, 'Management Carve-out')
    };

    /**
     * Resolve rate level for a given SIC code integer.
     * Returns RATE_LEVEL_NA if ineligible, RATE_LEVEL_2 if Level 2, else RATE_LEVEL_1.
     */
    public static String resolveRateLevel(Integer sicInt) {
        for (SICRange r : INELIGIBLE_SIC_RANGES) {
            if (r.contains(sicInt)) {
                return RATE_LEVEL_NA;
            }
        }
        for (SICRange r : LEVEL2_SIC_RANGES) {
            if (r.contains(sicInt)) {
                return RATE_LEVEL_2;
            }
        }
        return RATE_LEVEL_1;
    }
}
