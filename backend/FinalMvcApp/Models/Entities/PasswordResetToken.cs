using System.ComponentModel.DataAnnotations;

namespace FinalMvcApp.Models.Entities;

public class PasswordResetToken
{
    public int Id { get; set; }

    [Required]
    public int UserId { get; set; }

    [Required]
    [StringLength(128)]
    public string Token { get; set; } = string.Empty;

    [Required]
    public DateTime ExpiryDate { get; set; }

    public User User { get; set; } = null!;
}
