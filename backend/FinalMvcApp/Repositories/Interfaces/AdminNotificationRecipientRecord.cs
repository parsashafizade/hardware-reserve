namespace FinalMvcApp.Repositories.Interfaces;

public sealed record AdminNotificationRecipientRecord(
    int Id,
    string FullName,
    string Email);
