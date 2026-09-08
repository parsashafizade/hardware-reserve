using FinalMvcApp.Models.Enums;
using System.ComponentModel.DataAnnotations;

namespace FinalMvcApp.Models.Entities;

public class User
{
    public int Id { get; set; }

    [Required]
    [StringLength(200)]
    public string FullName { get; set; } = string.Empty;

    [Required]
    [StringLength(320)]
    public string Email { get; set; } = string.Empty;

    [Required]
    [StringLength(255)]
    public string PasswordHash { get; set; } = string.Empty;

    [Required]
    public UserRole Role { get; set; } = UserRole.User;

    [StringLength(500)]
    public string? ProfileImagePath { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public bool IsEmailVerified { get; set; }

    public DateTime? EmailVerifiedAt { get; set; }

    public ICollection<Reservation> Reservations { get; set; } = new List<Reservation>();
    public ICollection<EmailVerificationCode> EmailVerificationCodes { get; set; }
    = new List<EmailVerificationCode>();

    public ICollection<PasswordResetToken> PasswordResetTokens { get; set; } = new List<PasswordResetToken>();

    public ICollection<RefreshToken> RefreshTokens { get; set; } = new List<RefreshToken>();

    public ICollection<SupportConversation> SupportConversations { get; set; } = new List<SupportConversation>();

    public ICollection<SupportConversation> AssignedSupportConversations { get; set; } = new List<SupportConversation>();

    public ICollection<UserNotification> Notifications { get; set; } = new List<UserNotification>();

    public ICollection<PasswordResetCode> PasswordResetCodes { get; set; }
    = new List<PasswordResetCode>();
}
