/**
 * @description Custom exception for enrollment processing errors.
 *              Thrown by enrollment flows and Apex services when a member
 *              fails eligibility checks — e.g., duplicate enrollment,
 *              dependent age-out, waiting period violation, or plan
 *              not available for the member's coverage tier.
 * @author Enterprise Architecture Team
 * @date 2026-03
 */
public class DDEnrollmentException extends Exception {}
