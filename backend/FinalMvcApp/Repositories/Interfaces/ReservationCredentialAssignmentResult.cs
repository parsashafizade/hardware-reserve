using FinalMvcApp.Models.Entities;

namespace FinalMvcApp.Repositories.Interfaces;

public sealed record ReservationCredentialAssignmentResult(
    Reservation Reservation,
    bool IsEligible,
    bool Changed,
    bool WasPreviouslyAssigned,
    int ServiceDetailsVersion);
