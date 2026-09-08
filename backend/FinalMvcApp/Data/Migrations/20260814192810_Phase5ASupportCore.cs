using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FinalMvcApp.Data.Migrations
{
    /// <inheritdoc />
    public partial class Phase5ASupportCore : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "AnonymousSupportSessions",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    TokenHash = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    ExpiresAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    LastSeenAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    ClaimedByUserId = table.Column<int>(type: "integer", nullable: true),
                    ClaimedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AnonymousSupportSessions", x => x.Id);
                    table.ForeignKey(
                        name: "FK_AnonymousSupportSessions_Users_ClaimedByUserId",
                        column: x => x.ClaimedByUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "SupportQuickReplies",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Title = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: false),
                    Content = table.Column<string>(type: "character varying(2000)", maxLength: 2000, nullable: false),
                    Category = table.Column<string>(type: "character varying(80)", maxLength: 80, nullable: true),
                    IsActive = table.Column<bool>(type: "boolean", nullable: false),
                    SortOrder = table.Column<int>(type: "integer", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SupportQuickReplies", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "SupportConversations",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<int>(type: "integer", nullable: true),
                    AnonymousSessionId = table.Column<Guid>(type: "uuid", nullable: true),
                    Title = table.Column<string>(type: "character varying(160)", maxLength: 160, nullable: false),
                    Category = table.Column<string>(type: "character varying(80)", maxLength: 80, nullable: true),
                    Status = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    AssignedAdminUserId = table.Column<int>(type: "integer", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    ResolvedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    ClosedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    LastMessageSequence = table.Column<long>(type: "bigint", nullable: false),
                    LastMessageAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    LastMessagePreview = table.Column<string>(type: "character varying(240)", maxLength: 240, nullable: true),
                    LastMessageSender = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SupportConversations", x => x.Id);
                    table.CheckConstraint("CK_SupportConversations_ExactlyOneOwner", "(\"UserId\" IS NOT NULL AND \"AnonymousSessionId\" IS NULL) OR (\"UserId\" IS NULL AND \"AnonymousSessionId\" IS NOT NULL)");
                    table.CheckConstraint("CK_SupportConversations_LastMessageSequence", "\"LastMessageSequence\" >= 0");
                    table.ForeignKey(
                        name: "FK_SupportConversations_AnonymousSupportSessions_AnonymousSess~",
                        column: x => x.AnonymousSessionId,
                        principalTable: "AnonymousSupportSessions",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_SupportConversations_Users_AssignedAdminUserId",
                        column: x => x.AssignedAdminUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_SupportConversations_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "SupportConversationEvents",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    ConversationId = table.Column<Guid>(type: "uuid", nullable: false),
                    EventType = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: false),
                    ActorType = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    ActorUserId = table.Column<int>(type: "integer", nullable: true),
                    PreviousStatus = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: true),
                    NewStatus = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: true),
                    Details = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                    OccurredAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SupportConversationEvents", x => x.Id);
                    table.ForeignKey(
                        name: "FK_SupportConversationEvents_SupportConversations_Conversation~",
                        column: x => x.ConversationId,
                        principalTable: "SupportConversations",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_SupportConversationEvents_Users_ActorUserId",
                        column: x => x.ActorUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "SupportConversationReadStates",
                columns: table => new
                {
                    ConversationId = table.Column<Guid>(type: "uuid", nullable: false),
                    UserLastReadSequence = table.Column<long>(type: "bigint", nullable: false),
                    AdminLastReadSequence = table.Column<long>(type: "bigint", nullable: false),
                    UserUnreadCount = table.Column<int>(type: "integer", nullable: false),
                    AdminUnreadCount = table.Column<int>(type: "integer", nullable: false),
                    UserReadAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    AdminReadAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SupportConversationReadStates", x => x.ConversationId);
                    table.CheckConstraint("CK_SupportReadStates_Sequences", "\"UserLastReadSequence\" >= 0 AND \"AdminLastReadSequence\" >= 0");
                    table.CheckConstraint("CK_SupportReadStates_UnreadCounts", "\"UserUnreadCount\" >= 0 AND \"AdminUnreadCount\" >= 0");
                    table.ForeignKey(
                        name: "FK_SupportConversationReadStates_SupportConversations_Conversa~",
                        column: x => x.ConversationId,
                        principalTable: "SupportConversations",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "SupportMessages",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    ConversationId = table.Column<Guid>(type: "uuid", nullable: false),
                    SequenceNumber = table.Column<long>(type: "bigint", nullable: false),
                    SenderType = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    SenderUserId = table.Column<int>(type: "integer", nullable: true),
                    Content = table.Column<string>(type: "character varying(4000)", maxLength: 4000, nullable: false),
                    ClientMessageId = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SupportMessages", x => x.Id);
                    table.CheckConstraint("CK_SupportMessages_SequenceNumber", "\"SequenceNumber\" > 0");
                    table.ForeignKey(
                        name: "FK_SupportMessages_SupportConversations_ConversationId",
                        column: x => x.ConversationId,
                        principalTable: "SupportConversations",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_SupportMessages_Users_SenderUserId",
                        column: x => x.SenderUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "SupportMessageAttachments",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    MessageId = table.Column<Guid>(type: "uuid", nullable: false),
                    FileName = table.Column<string>(type: "character varying(255)", maxLength: 255, nullable: false),
                    ContentType = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: false),
                    StorageKey = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false),
                    SizeBytes = table.Column<long>(type: "bigint", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SupportMessageAttachments", x => x.Id);
                    table.CheckConstraint("CK_SupportMessageAttachments_SizeBytes", "\"SizeBytes\" >= 0");
                    table.ForeignKey(
                        name: "FK_SupportMessageAttachments_SupportMessages_MessageId",
                        column: x => x.MessageId,
                        principalTable: "SupportMessages",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_AnonymousSupportSessions_ClaimedByUserId",
                table: "AnonymousSupportSessions",
                column: "ClaimedByUserId");

            migrationBuilder.CreateIndex(
                name: "IX_AnonymousSupportSessions_ExpiresAt",
                table: "AnonymousSupportSessions",
                column: "ExpiresAt");

            migrationBuilder.CreateIndex(
                name: "IX_AnonymousSupportSessions_TokenHash",
                table: "AnonymousSupportSessions",
                column: "TokenHash",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_SupportConversationEvents_ActorUserId",
                table: "SupportConversationEvents",
                column: "ActorUserId");

            migrationBuilder.CreateIndex(
                name: "IX_SupportConversationEvents_ConversationId_OccurredAt_Id",
                table: "SupportConversationEvents",
                columns: new[] { "ConversationId", "OccurredAt", "Id" });

            migrationBuilder.CreateIndex(
                name: "IX_SupportConversationEvents_EventType",
                table: "SupportConversationEvents",
                column: "EventType");

            migrationBuilder.CreateIndex(
                name: "IX_SupportConversations_AnonymousSessionId_UpdatedAt_Id",
                table: "SupportConversations",
                columns: new[] { "AnonymousSessionId", "UpdatedAt", "Id" });

            migrationBuilder.CreateIndex(
                name: "IX_SupportConversations_AssignedAdminUserId",
                table: "SupportConversations",
                column: "AssignedAdminUserId");

            migrationBuilder.CreateIndex(
                name: "IX_SupportConversations_Status_UpdatedAt_Id",
                table: "SupportConversations",
                columns: new[] { "Status", "UpdatedAt", "Id" });

            migrationBuilder.CreateIndex(
                name: "IX_SupportConversations_UserId_UpdatedAt_Id",
                table: "SupportConversations",
                columns: new[] { "UserId", "UpdatedAt", "Id" });

            migrationBuilder.CreateIndex(
                name: "IX_SupportMessageAttachments_MessageId",
                table: "SupportMessageAttachments",
                column: "MessageId");

            migrationBuilder.CreateIndex(
                name: "IX_SupportMessageAttachments_StorageKey",
                table: "SupportMessageAttachments",
                column: "StorageKey",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_SupportMessages_ConversationId_SenderType_ClientMessageId",
                table: "SupportMessages",
                columns: new[] { "ConversationId", "SenderType", "ClientMessageId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_SupportMessages_ConversationId_SequenceNumber",
                table: "SupportMessages",
                columns: new[] { "ConversationId", "SequenceNumber" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_SupportMessages_SenderUserId",
                table: "SupportMessages",
                column: "SenderUserId");

            migrationBuilder.CreateIndex(
                name: "IX_SupportQuickReplies_IsActive_SortOrder_Title",
                table: "SupportQuickReplies",
                columns: new[] { "IsActive", "SortOrder", "Title" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "SupportConversationEvents");

            migrationBuilder.DropTable(
                name: "SupportConversationReadStates");

            migrationBuilder.DropTable(
                name: "SupportMessageAttachments");

            migrationBuilder.DropTable(
                name: "SupportQuickReplies");

            migrationBuilder.DropTable(
                name: "SupportMessages");

            migrationBuilder.DropTable(
                name: "SupportConversations");

            migrationBuilder.DropTable(
                name: "AnonymousSupportSessions");
        }
    }
}
