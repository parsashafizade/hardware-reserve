namespace FinalMvcApp.DTOs.Admin;

public class AdminOrderDto
{
    public int ReservationId { get; set; }

    public int UserId { get; set; }

    public string UserFullName { get; set; } = string.Empty;

    public string UserEmail { get; set; } = string.Empty;

    public int ServerId { get; set; }

    public string CPU { get; set; } = string.Empty;

    public string GPU { get; set; } = string.Empty;

    public string RAM { get; set; } = string.Empty;

    public string Storage { get; set; } = string.Empty;

    public string OS { get; set; } = string.Empty;

    public DateTime StartTime { get; set; }

    public DateTime EndTime { get; set; }

    public decimal TotalPrice { get; set; }

    public string ReservationStatus { get; set; } = string.Empty;

    public string PaymentStatus { get; set; } = "Unpaid";

    // Deliberately exposes only provisioning state. Connection secrets remain
    // confined to owner-facing service responses and the protected Admin detail.
    public bool CredentialsAssigned { get; set; }

    public string AssignmentStatus { get; set; } = "NotAssigned";
}
