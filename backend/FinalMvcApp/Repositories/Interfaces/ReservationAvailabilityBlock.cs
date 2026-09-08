namespace FinalMvcApp.Repositories.Interfaces;

public sealed record ReservationAvailabilityBlock(
    int? ReservationId,
    DateTime StartTime,
    DateTime EndTime,
    bool IsMaintenance);
