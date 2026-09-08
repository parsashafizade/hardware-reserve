using System.ComponentModel.DataAnnotations;

namespace FinalMvcApp.Models.Entities;

public class SupportMessageAttachment
{
    public Guid Id { get; set; }

    public Guid MessageId { get; set; }

    [Required]
    [StringLength(255)]
    public string FileName { get; set; } = string.Empty;

    [Required]
    [StringLength(120)]
    public string ContentType { get; set; } = string.Empty;

    [Required]
    [StringLength(500)]
    public string StorageKey { get; set; } = string.Empty;

    public long SizeBytes { get; set; }

    public DateTime CreatedAt { get; set; }

    public SupportMessage Message { get; set; } = null!;
}
