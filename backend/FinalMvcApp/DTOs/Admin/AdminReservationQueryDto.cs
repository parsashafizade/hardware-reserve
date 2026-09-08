namespace FinalMvcApp.DTOs.Admin;

public class AdminReservationQueryDto
{
    public string? Query { get; set; }

    public string? Status { get; set; }

    public string? AssignmentStatus { get; set; }

    public int Page { get; set; } = 1;

    public int PageSize { get; set; } = 20;
}
