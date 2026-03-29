/**
 * @description Custom exception for rating engine errors.
 *              Thrown by DDRatingEngineService when premium calculation fails —
 *              e.g., missing rate table, ineligible SIC code at rating time,
 *              or census data that prevents composite rate calculation.
 * @author Enterprise Architecture Team
 * @date 2026-03
 */
public class DDRatingException extends Exception {}
