using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FinalMvcApp.Data.Migrations
{
    /// <inheritdoc />
    public partial class Phase5BSupportAiLayer : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "AiHandoffGeneratedAt",
                table: "SupportConversations",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "AiHandoffReason",
                table: "SupportConversations",
                type: "character varying(120)",
                maxLength: 120,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "AiHandoffSummary",
                table: "SupportConversations",
                type: "character varying(2000)",
                maxLength: 2000,
                nullable: true);

            migrationBuilder.CreateTable(
                name: "SupportAiProcessings",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    ConversationId = table.Column<Guid>(type: "uuid", nullable: false),
                    UserMessageId = table.Column<Guid>(type: "uuid", nullable: false),
                    AiMessageId = table.Column<Guid>(type: "uuid", nullable: true),
                    Status = table.Column<string>(type: "character varying(24)", maxLength: 24, nullable: false),
                    AttemptCount = table.Column<int>(type: "integer", nullable: false),
                    Provider = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: false),
                    Model = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    FailureCode = table.Column<string>(type: "character varying(80)", maxLength: 80, nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    StartedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    LeaseExpiresAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    CompletedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SupportAiProcessings", x => x.Id);
                    table.CheckConstraint("CK_SupportAiProcessings_AttemptCount", "\"AttemptCount\" > 0");
                    table.ForeignKey(
                        name: "FK_SupportAiProcessings_SupportConversations_ConversationId",
                        column: x => x.ConversationId,
                        principalTable: "SupportConversations",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_SupportAiProcessings_SupportMessages_AiMessageId",
                        column: x => x.AiMessageId,
                        principalTable: "SupportMessages",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_SupportAiProcessings_SupportMessages_UserMessageId",
                        column: x => x.UserMessageId,
                        principalTable: "SupportMessages",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_SupportAiProcessings_AiMessageId",
                table: "SupportAiProcessings",
                column: "AiMessageId");

            migrationBuilder.CreateIndex(
                name: "IX_SupportAiProcessings_ConversationId_Status",
                table: "SupportAiProcessings",
                columns: new[] { "ConversationId", "Status" });

            migrationBuilder.CreateIndex(
                name: "IX_SupportAiProcessings_LeaseExpiresAt",
                table: "SupportAiProcessings",
                column: "LeaseExpiresAt");

            migrationBuilder.CreateIndex(
                name: "IX_SupportAiProcessings_UserMessageId",
                table: "SupportAiProcessings",
                column: "UserMessageId",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "SupportAiProcessings");

            migrationBuilder.DropColumn(
                name: "AiHandoffGeneratedAt",
                table: "SupportConversations");

            migrationBuilder.DropColumn(
                name: "AiHandoffReason",
                table: "SupportConversations");

            migrationBuilder.DropColumn(
                name: "AiHandoffSummary",
                table: "SupportConversations");
        }
    }
}
