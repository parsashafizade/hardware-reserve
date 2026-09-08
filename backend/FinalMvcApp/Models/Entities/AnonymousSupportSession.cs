using System.ComponentModel.DataAnnotations;

namespace FinalMvcApp.Models.Entities;

public class AnonymousSupportSession
{
    public Guid Id { get; set; }

    [Required]
    [StringLength(64)]
    public string TokenHash { get; set; } = string.Empty;

    public DateTime CreatedAt { get; set; }

    public DateTime ExpiresAt { get; set; }

    public DateTime LastSeenAt { get; set; }

    public int? ClaimedByUserId { get; set; }

    public DateTime? ClaimedAt { get; set; }

    public User? ClaimedByUser { get; set; }

    public ICollection<SupportConversation> Conversations { get; set; } = new List<SupportConversation>();
}
