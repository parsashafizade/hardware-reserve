namespace FinalMvcApp.Models.Enums;

public enum AdminAuditAction
{
    MaintenanceCreated = 1,
    MaintenanceRemoved = 2,
    ManualNotificationSent = 3,
    BroadcastNotificationSent = 4,
    ReservationCancelled = 5,
    CredentialsAssigned = 6,
    ServerCreated = 7,
    ServerConfigurationChanged = 8,
    ServerDisabled = 9,
    AdminAccountCreated = 10
}
