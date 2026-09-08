using FinalMvcApp.Models.Enums;
using System.ComponentModel.DataAnnotations;

namespace FinalMvcApp.Models.Entities;

public class Reservation
{
    public int Id { get; set; }

    [Required]
    public int UserId { get; set; }

    [Required]
    public int ServerId { get; set; }

    [Required]
    public DateTime StartTime { get; set; }

    [Required]
    public DateTime EndTime { get; set; }

    [Range(typeof(decimal), "0", "9999999999999999.99")]
    public decimal TotalPrice { get; set; }

    [Required]
    public ReservationStatus Status { get; set; } = ReservationStatus.PendingPayment;

    [StringLength(100)]
    public string? AssignedIp { get; set; }

    [StringLength(100)]
    public string? AssignedUsername { get; set; }

    [StringLength(100)]
    public string? AssignedPassword { get; set; }

    public int ServiceDetailsVersion { get; set; }

    public int ServiceDetailsNotifiedVersion { get; set; }

    public bool StartedNotificationDelivered { get; set; }

    public bool CompletedNotificationDelivered { get; set; }

    public User User { get; set; } = null!;

    public Server Server { get; set; } = null!;

    public Payment? Payment { get; set; }

    public ICollection<UserNotification> Notifications { get; set; } = new List<UserNotification>();
}
