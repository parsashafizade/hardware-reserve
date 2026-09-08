using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace FinalMvcApp.DTOs.Profile;

public class UploadProfileImageRequest
{
    [Required]
    [FromForm(Name = "file")]
    public IFormFile File { get; set; } = null!;
}
