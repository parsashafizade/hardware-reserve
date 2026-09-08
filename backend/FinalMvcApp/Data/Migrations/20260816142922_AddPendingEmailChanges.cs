using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FinalMvcApp.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddPendingEmailChanges : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "PendingEmailChanges",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<int>(type: "integer", nullable: false),
                    CurrentEmail = table.Column<string>(type: "character varying(320)", maxLength: 320, nullable: false),
                    NewEmail = table.Column<string>(type: "character varying(320)", maxLength: 320, nullable: false),
                    CurrentCodeHash = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    NewCodeHash = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    CurrentCodeCreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    NewCodeCreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    CurrentCodeExpiresAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    NewCodeExpiresAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    CurrentCodeUsedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    NewCodeUsedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    CurrentAttemptCount = table.Column<int>(type: "integer", nullable: false),
                    NewAttemptCount = table.Column<int>(type: "integer", nullable: false),
                    CurrentEmailVerifiedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    NewEmailVerifiedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    ExpiresAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    CompletedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    InvalidatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PendingEmailChanges", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PendingEmailChanges_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_PendingEmailChanges_NewEmail",
                table: "PendingEmailChanges",
                column: "NewEmail");

            migrationBuilder.CreateIndex(
                name: "IX_PendingEmailChanges_UserId",
                table: "PendingEmailChanges",
                column: "UserId",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "PendingEmailChanges");
        }
    }
}
