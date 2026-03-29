/**
 * @description Service class for managing DD_Quote_Plan_Config__c records.
 *
 *              This is the gateway between the master catalog (read-only) and the
 *              quote layer (agent-editable). The key method createConfigFromDefaults()
 *              copies master catalog defaults into a new agent-configurable record.
 *              Agents then modify ONLY DD_Quote_Plan_Config__c — never the master.
 *
 *              Design rule: every write to DD_Quote_Plan_Config__c must pass through
 *              validateConfig() before DML is committed.
 *
 * @author Enterprise Architecture Team
 * @date 2026-03
 */
public with sharing class DDQuoteConfigService {

    // Config_Status__c picklist values
    private static final String STATUS_DRAFT      = 'Draft';
    private static final String STATUS_CONFIGURED = 'Configured';

    // Contribution_Type__c picklist values (matches field definition)
    private static final String CONTRIB_TYPE_PCT    = 'Percentage';
    private static final String CONTRIB_TYPE_DOLLAR = 'Dollar Amount';

    // ─────────────────────────────────────────────────────────────────────────
    // PUBLIC METHODS
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @description THE KEY METHOD — creates a DD_Quote_Plan_Config__c pre-populated
     *              with defaults sourced from the master catalog.
     *
     *              Defaults applied:
     *                • Selected_Annual_Max__c    = first value in Available_Annual_Maxes__c
     *                • Employer_Contribution_Pct__c = Min_Contribution_Pct__c (floor)
     *                • Contribution_Type__c      = 'Percentage'
     *                • Rate_Guarantee_Months__c  = DDConstants.RATE_GUARANTEE_MONTHS (12)
     *                • Waiting_Period_Waived__c  = false (conservative default)
     *                • DnP_Waiver_Selected__c    = false
     *                • Config_Status__c          = 'Draft'
     *                • Selected_Ortho_Type__c    = first type in Available_Ortho_Types__c (if ortho product)
     *                • Selected_Ortho_Max__c     = first value in Available_Ortho_Maxes__c (if ortho product)
     *
     *              Idempotent: if a config already exists for this quote+product combo,
     *              returns the existing record without modifying it.
     *
     * @param quoteId        The parent Quote record Id
     * @param productId      The DD_Product__c record Id
     * @param sellingModelId The DD_Selling_Model__c record Id for this segment
     * @return The newly created (or pre-existing) DD_Quote_Plan_Config__c
     * @throws DDValidationException for missing parameters or missing selling model
     */
    public static DD_Quote_Plan_Config__c createConfigFromDefaults(
        Id quoteId,
        Id productId,
        Id sellingModelId
    ) {
        if (quoteId == null || productId == null || sellingModelId == null) {
            throw new DDValidationException(
                'quoteId, productId, and sellingModelId are all required for createConfigFromDefaults'
            );
        }

        // Idempotency: return existing config if already created
        List<DD_Quote_Plan_Config__c> existing = [
            SELECT Id, Config_Status__c
            FROM DD_Quote_Plan_Config__c
            WHERE Quote__c = :quoteId
              AND Product__c = :productId
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            return existing[0];
        }

        // Load the selling model to source defaults
        List<DD_Selling_Model__c> models = [
            SELECT Id, Min_Contribution_Pct__c, Available_Annual_Maxes__c,
                   Available_Ortho_Types__c, Available_Ortho_Maxes__c,
                   Waiting_Period_Months__c, Waiting_Period_Waiver_Allowed__c
            FROM DD_Selling_Model__c
            WHERE Id = :sellingModelId
            LIMIT 1
        ];
        if (models.isEmpty()) {
            throw new DDValidationException(
                'Selling model ' + sellingModelId + ' not found. Cannot create config.'
            );
        }
        DD_Selling_Model__c sm = models[0];

        // Load product to check ortho availability
        List<DD_Product__c> products = [
            SELECT Id, Ortho_Available__c
            FROM DD_Product__c
            WHERE Id = :productId
            LIMIT 1
        ];
        if (products.isEmpty()) {
            throw new DDValidationException('Product ' + productId + ' not found.');
        }
        Boolean orthoAvailable = products[0].Ortho_Available__c == true;

        // Build the config record with catalog defaults
        DD_Quote_Plan_Config__c config = new DD_Quote_Plan_Config__c(
            Quote__c              = quoteId,
            Product__c            = productId,
            Selling_Model__c      = sellingModelId,
            Config_Status__c      = STATUS_DRAFT,
            Contribution_Type__c  = CONTRIB_TYPE_PCT,
            Rate_Guarantee_Months__c = DDConstants.RATE_GUARANTEE_MONTHS,
            Waiting_Period_Waived__c = false,
            DnP_Waiver_Selected__c   = false
        );

        // Default employer contribution = selling model minimum (floor)
        if (sm.Min_Contribution_Pct__c != null) {
            config.Employer_Contribution_Pct__c = sm.Min_Contribution_Pct__c;
        }

        // Default annual max = first entry in the allowed list
        config.Selected_Annual_Max__c = parseFirstDecimal(sm.Available_Annual_Maxes__c);

        // Default ortho options (only if product supports ortho)
        if (orthoAvailable) {
            config.Selected_Ortho_Type__c = parseFirstString(sm.Available_Ortho_Types__c);
            config.Selected_Ortho_Max__c  = parseFirstDecimal(sm.Available_Ortho_Maxes__c);
        }

        insert config;
        return config;
    }

    /**
     * @description Validates and saves agent changes to a DD_Quote_Plan_Config__c.
     *              Agents may ONLY modify the Quote layer — the master catalog
     *              fields (Product__c, Selling_Model__c) must not be changed.
     *
     *              Raises DDValidationException before any DML if validation fails.
     *
     * @param config  The modified DD_Quote_Plan_Config__c to save
     * @throws DDValidationException if any field fails constraint validation
     */
    public static void updateConfig(DD_Quote_Plan_Config__c config) {
        validateConfig(config);

        // Mark as Configured once the agent has made at least one deliberate save
        if (config.Config_Status__c == STATUS_DRAFT) {
            config.Config_Status__c = STATUS_CONFIGURED;
        }

        update config;
    }

    /**
     * @description Validates agent-supplied values against the constraints defined
     *              in the associated DD_Selling_Model__c.
     *
     *              Checks:
     *                1. Selected_Annual_Max__c is in the selling model's allowed list
     *                2. Employer_Contribution_Pct__c >= Min_Contribution_Pct__c
     *                3. Selected_Ortho_Type__c is in the allowed ortho types list
     *                4. Selected_Ortho_Max__c is in the allowed ortho maxes list
     *                5. Core Buy-Up: minimum 50% employer contribution enforced
     *
     * @param config  The DD_Quote_Plan_Config__c with agent-supplied values
     * @throws DDValidationException listing all constraint violations found
     */
    public static void validateConfig(DD_Quote_Plan_Config__c config) {
        if (config == null) {
            throw new DDValidationException('Config record cannot be null');
        }

        // Reload the selling model to get current constraint values
        if (config.Selling_Model__c == null) {
            throw new DDValidationException('Config must have a Selling_Model__c before validation');
        }

        List<DD_Selling_Model__c> models = [
            SELECT Id, Min_Contribution_Pct__c, Available_Annual_Maxes__c,
                   Available_Ortho_Types__c, Available_Ortho_Maxes__c
            FROM DD_Selling_Model__c
            WHERE Id = :config.Selling_Model__c
            LIMIT 1
        ];
        if (models.isEmpty()) {
            throw new DDValidationException('Selling model not found: ' + config.Selling_Model__c);
        }
        DD_Selling_Model__c sm = models[0];

        // Load product for plan-family-specific rules
        List<DD_Product__c> products = [
            SELECT Id, Plan_Family__c, Ortho_Available__c
            FROM DD_Product__c
            WHERE Id = :config.Product__c
            LIMIT 1
        ];
        DD_Product__c product = products.isEmpty() ? null : products[0];

        List<String> errors = new List<String>();

        // 1. Annual max in allowed list
        if (config.Selected_Annual_Max__c != null
                && !String.isBlank(sm.Available_Annual_Maxes__c)) {
            List<Decimal> allowedMaxes = parseDecimalList(sm.Available_Annual_Maxes__c);
            if (!allowedMaxes.contains(config.Selected_Annual_Max__c)) {
                errors.add(
                    'Selected Annual Max $' + config.Selected_Annual_Max__c.setScale(0)
                    + ' is not in the allowed list: ' + sm.Available_Annual_Maxes__c
                );
            }
        }

        // 2. Employer contribution >= floor
        if (config.Employer_Contribution_Pct__c != null
                && sm.Min_Contribution_Pct__c != null
                && config.Employer_Contribution_Pct__c < sm.Min_Contribution_Pct__c) {
            errors.add(
                'Employer contribution ' + config.Employer_Contribution_Pct__c + '% '
                + 'is below the minimum ' + sm.Min_Contribution_Pct__c + '% for this plan.'
            );
        }

        // 3. Core Buy-Up: hard 50% floor regardless of selling model value
        if (product != null
                && product.Plan_Family__c == DDConstants.PLAN_FAMILY_CORE_BUYUP
                && (config.Employer_Contribution_Pct__c == null
                    || config.Employer_Contribution_Pct__c < DDConstants.MIN_CONTRIBUTION_CORE_BUYUP)) {
            errors.add(
                'Core Buy-Up plans require a minimum ' + DDConstants.MIN_CONTRIBUTION_CORE_BUYUP
                + '% employer contribution.'
            );
        }

        // 4. Ortho type in allowed list (only if ortho selected)
        if (!String.isBlank(config.Selected_Ortho_Type__c)
                && !String.isBlank(sm.Available_Ortho_Types__c)) {
            List<String> allowedTypes = parseStringList(sm.Available_Ortho_Types__c);
            if (!allowedTypes.contains(config.Selected_Ortho_Type__c)) {
                errors.add(
                    'Selected Ortho Type "' + config.Selected_Ortho_Type__c
                    + '" is not in the allowed list: ' + sm.Available_Ortho_Types__c
                );
            }
        }

        // 5. Ortho max in allowed list (only if ortho selected)
        if (config.Selected_Ortho_Max__c != null
                && !String.isBlank(sm.Available_Ortho_Maxes__c)) {
            List<Decimal> allowedOrthoMaxes = parseDecimalList(sm.Available_Ortho_Maxes__c);
            if (!allowedOrthoMaxes.contains(config.Selected_Ortho_Max__c)) {
                errors.add(
                    'Selected Ortho Max $' + config.Selected_Ortho_Max__c.setScale(0)
                    + ' is not in the allowed list: ' + sm.Available_Ortho_Maxes__c
                );
            }
        }

        if (!errors.isEmpty()) {
            throw new DDValidationException(
                'Quote config validation failed:\n• ' + String.join(errors, '\n• ')
            );
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // PRIVATE HELPERS
    // ─────────────────────────────────────────────────────────────────────────

    private static Decimal parseFirstDecimal(String csv) {
        if (String.isBlank(csv)) {
            return null;
        }
        List<String> parts = csv.split(',');
        for (String part : parts) {
            String trimmed = part.trim();
            if (String.isNotBlank(trimmed) && trimmed.isNumeric()) {
                return Decimal.valueOf(trimmed);
            }
        }
        return null;
    }

    private static String parseFirstString(String csv) {
        if (String.isBlank(csv)) {
            return null;
        }
        List<String> parts = csv.split(',');
        for (String part : parts) {
            String trimmed = part.trim();
            if (String.isNotBlank(trimmed)) {
                return trimmed;
            }
        }
        return null;
    }

    private static List<Decimal> parseDecimalList(String csv) {
        List<Decimal> result = new List<Decimal>();
        if (String.isBlank(csv)) {
            return result;
        }
        for (String part : csv.split(',')) {
            String trimmed = part.trim();
            if (String.isNotBlank(trimmed) && trimmed.isNumeric()) {
                result.add(Decimal.valueOf(trimmed));
            }
        }
        return result;
    }

    private static List<String> parseStringList(String csv) {
        List<String> result = new List<String>();
        if (String.isBlank(csv)) {
            return result;
        }
        for (String part : csv.split(',')) {
            String trimmed = part.trim();
            if (String.isNotBlank(trimmed)) {
                result.add(trimmed);
            }
        }
        return result;
    }
}
