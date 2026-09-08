using FinalMvcApp.Services.Interfaces;

namespace FinalMvcApp.Services.Implementations;

public class SupportKnowledgeSource : ISupportKnowledgeSource
{
    private const string Knowledge = """
        HARDWARERESERVE APPROVED SUPPORT KNOWLEDGE

        VERIFIED IMPLEMENTATION FACTS
        - Public visitors can browse active servers and view CPU, GPU, RAM, storage, operating system, hourly price, and daily price.
        - The public server catalog supports optional CPU, GPU, RAM, storage, and operating-system filters.
        - Creating a reservation requires authentication, an active server, a future UTC start time, and an end time after the start time.
        - A reservation is rejected when it overlaps a non-cancelled reservation for the same server.
        - Durations below 24 hours use hourly pricing. Durations of 24 hours or more use whole daily-price units plus hourly pricing for remaining hours.
        - New reservations begin in PendingPayment status. Successful checkout records a completed payment and changes the reservation to Paid.
        - Paid reservations appear in My Services. Connection details appear there only after an administrator assigns them.
        - Users can view their reservation history, paid services, profile, and payment state after authentication.
        - Profile image, password reset, login, and registration flows exist. Login and registration require the server-verified math captcha.
        - The implementation has no user-facing reservation cancellation or modification operation.

        CONFIRMED PRODUCT-OWNER POLICIES
        - Reservation cancellation is not supported.
        - Refund requests require administrator review. Automated support must not promise, approve, reject, or determine refund eligibility.
        - Credentials are normally assigned between 10 minutes and 24 hours after successful payment.
        - If more than 24 hours have passed after successful payment and credentials are still not assigned, human support is required.
        - Guests may receive general pre-purchase and product support. Account-specific assistance requires authentication.

        KNOWLEDGE LIMITS
        - A missing feature is not a product policy unless explicitly listed above.
        - Do not invent refund eligibility, service-level guarantees, locations, stock, discounts, payment methods, cancellation exceptions, or provisioning promises.
        - Current server inventory and authenticated account state are supplied separately by backend-controlled read-only context when authorized.
        """;

    public string GetApprovedKnowledge() => Knowledge;
}
