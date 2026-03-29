/**
 * @description Custom exception for input validation failures.
 *              Thrown by selector and service classes when required parameters
 *              are missing or malformed — e.g., blank SIC code, null productId,
 *              or a group size below the platform minimum.
 *              Catch this in LWC error handlers to surface user-friendly messages.
 * @author Enterprise Architecture Team
 * @date 2026-03
 */
public class DDValidationException extends Exception {}
