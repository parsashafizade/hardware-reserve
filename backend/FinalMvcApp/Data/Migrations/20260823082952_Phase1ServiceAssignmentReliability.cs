using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FinalMvcApp.Data.Migrations
{
    /// <inheritdoc />
    public partial class Phase1ServiceAssignmentReliability : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "ServiceDetailsNotifiedVersion",
                table: "Reservations",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<int>(
                name: "ServiceDetailsVersion",
                table: "Reservations",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.CreateIndex(
                name: "IX_Reservations_PendingServiceDetailsNotification",
                table: "Reservations",
                column: "Id",
                filter: "\"ServiceDetailsVersion\" > \"ServiceDetailsNotifiedVersion\"");

            migrationBuilder.AddCheckConstraint(
                name: "CK_Reservations_ServiceDetailsVersions",
                table: "Reservations",
                sql: "\"ServiceDetailsNotifiedVersion\" >= 0 AND \"ServiceDetailsNotifiedVersion\" <= \"ServiceDetailsVersion\"");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Reservations_PendingServiceDetailsNotification",
                table: "Reservations");

            migrationBuilder.DropCheckConstraint(
                name: "CK_Reservations_ServiceDetailsVersions",
                table: "Reservations");

            migrationBuilder.DropColumn(
                name: "ServiceDetailsNotifiedVersion",
                table: "Reservations");

            migrationBuilder.DropColumn(
                name: "ServiceDetailsVersion",
                table: "Reservations");
        }
    }
}
