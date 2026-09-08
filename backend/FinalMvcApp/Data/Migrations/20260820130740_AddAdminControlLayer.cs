using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FinalMvcApp.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddAdminControlLayer : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "AdminCampaignId",
                table: "UserNotifications",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "CreatedByAdminUserId",
                table: "UserNotifications",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Message",
                table: "UserNotifications",
                type: "character varying(1000)",
                maxLength: 1000,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Source",
                table: "UserNotifications",
                type: "character varying(20)",
                maxLength: 20,
                nullable: false,
                defaultValue: "System");

            migrationBuilder.AddColumn<string>(
                name: "Title",
                table: "UserNotifications",
                type: "character varying(120)",
                maxLength: 120,
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "CpuCapabilityLevel",
                table: "Servers",
                type: "integer",
                nullable: false,
                defaultValue: 50);

            migrationBuilder.AddColumn<bool>(
                name: "FinderEligible",
                table: "Servers",
                type: "boolean",
                nullable: false,
                defaultValue: true);

            migrationBuilder.AddColumn<int>(
                name: "GpuCapabilityLevel",
                table: "Servers",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<string>(
                name: "OperationalStatus",
                table: "Servers",
                type: "character varying(40)",
                maxLength: 40,
                nullable: false,
                defaultValue: "Available");

            migrationBuilder.AddColumn<string>(
                name: "PerformanceTier",
                table: "Servers",
                type: "character varying(20)",
                maxLength: 20,
                nullable: false,
                defaultValue: "Standard");

            migrationBuilder.Sql(
                "UPDATE \"Servers\" SET \"OperationalStatus\" = 'Disabled', \"FinderEligible\" = FALSE WHERE \"IsActive\" = FALSE;");

            migrationBuilder.CreateTable(
                name: "AdminAuditEvents",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    AdminUserId = table.Column<int>(type: "integer", nullable: false),
                    Action = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    EntityType = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    EntityId = table.Column<string>(type: "character varying(80)", maxLength: 80, nullable: false),
                    Details = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AdminAuditEvents", x => x.Id);
                    table.ForeignKey(
                        name: "FK_AdminAuditEvents_Users_AdminUserId",
                        column: x => x.AdminUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "AdminNotificationCampaigns",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    CreatedByAdminUserId = table.Column<int>(type: "integer", nullable: false),
                    RecipientScope = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    RecipientUserId = table.Column<int>(type: "integer", nullable: true),
                    Title = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: false),
                    Message = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: false),
                    Category = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: false),
                    TargetCount = table.Column<int>(type: "integer", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AdminNotificationCampaigns", x => x.Id);
                    table.ForeignKey(
                        name: "FK_AdminNotificationCampaigns_Users_CreatedByAdminUserId",
                        column: x => x.CreatedByAdminUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_AdminNotificationCampaigns_Users_RecipientUserId",
                        column: x => x.RecipientUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "ServerMaintenanceWindows",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    ServerId = table.Column<int>(type: "integer", nullable: false),
                    StartTime = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    EndTime = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    Reason = table.Column<string>(type: "character varying(300)", maxLength: 300, nullable: true),
                    CreatedByAdminUserId = table.Column<int>(type: "integer", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ServerMaintenanceWindows", x => x.Id);
                    table.CheckConstraint("CK_ServerMaintenanceWindows_TimeRange", "\"StartTime\" < \"EndTime\"");
                    table.ForeignKey(
                        name: "FK_ServerMaintenanceWindows_Servers_ServerId",
                        column: x => x.ServerId,
                        principalTable: "Servers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_ServerMaintenanceWindows_Users_CreatedByAdminUserId",
                        column: x => x.CreatedByAdminUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "ServerWorkloadCapabilities",
                columns: table => new
                {
                    ServerId = table.Column<int>(type: "integer", nullable: false),
                    WorkloadType = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: false),
                    SuitabilityLevel = table.Column<byte>(type: "smallint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ServerWorkloadCapabilities", x => new { x.ServerId, x.WorkloadType });
                    table.CheckConstraint("CK_ServerWorkloadCapabilities_SuitabilityLevel", "\"SuitabilityLevel\" BETWEEN 1 AND 5");
                    table.ForeignKey(
                        name: "FK_ServerWorkloadCapabilities_Servers_ServerId",
                        column: x => x.ServerId,
                        principalTable: "Servers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_UserNotifications_AdminCampaignId",
                table: "UserNotifications",
                column: "AdminCampaignId");

            migrationBuilder.CreateIndex(
                name: "IX_UserNotifications_CreatedByAdminUserId",
                table: "UserNotifications",
                column: "CreatedByAdminUserId");

            migrationBuilder.CreateIndex(
                name: "IX_Servers_FinderEligible",
                table: "Servers",
                column: "FinderEligible");

            migrationBuilder.CreateIndex(
                name: "IX_Servers_OperationalStatus",
                table: "Servers",
                column: "OperationalStatus");

            migrationBuilder.AddCheckConstraint(
                name: "CK_Servers_CpuCapabilityLevel",
                table: "Servers",
                sql: "\"CpuCapabilityLevel\" BETWEEN 0 AND 100");

            migrationBuilder.AddCheckConstraint(
                name: "CK_Servers_GpuCapabilityLevel",
                table: "Servers",
                sql: "\"GpuCapabilityLevel\" BETWEEN 0 AND 100");

            migrationBuilder.CreateIndex(
                name: "IX_AdminAuditEvents_AdminUserId",
                table: "AdminAuditEvents",
                column: "AdminUserId");

            migrationBuilder.CreateIndex(
                name: "IX_AdminAuditEvents_CreatedAt",
                table: "AdminAuditEvents",
                column: "CreatedAt");

            migrationBuilder.CreateIndex(
                name: "IX_AdminAuditEvents_EntityType_EntityId",
                table: "AdminAuditEvents",
                columns: new[] { "EntityType", "EntityId" });

            migrationBuilder.CreateIndex(
                name: "IX_AdminNotificationCampaigns_CreatedAt",
                table: "AdminNotificationCampaigns",
                column: "CreatedAt");

            migrationBuilder.CreateIndex(
                name: "IX_AdminNotificationCampaigns_CreatedByAdminUserId",
                table: "AdminNotificationCampaigns",
                column: "CreatedByAdminUserId");

            migrationBuilder.CreateIndex(
                name: "IX_AdminNotificationCampaigns_RecipientUserId",
                table: "AdminNotificationCampaigns",
                column: "RecipientUserId");

            migrationBuilder.CreateIndex(
                name: "IX_ServerMaintenanceWindows_CreatedByAdminUserId",
                table: "ServerMaintenanceWindows",
                column: "CreatedByAdminUserId");

            migrationBuilder.CreateIndex(
                name: "IX_ServerMaintenanceWindows_ServerId_StartTime_EndTime",
                table: "ServerMaintenanceWindows",
                columns: new[] { "ServerId", "StartTime", "EndTime" });

            migrationBuilder.CreateIndex(
                name: "IX_ServerWorkloadCapabilities_WorkloadType",
                table: "ServerWorkloadCapabilities",
                column: "WorkloadType");

            migrationBuilder.AddForeignKey(
                name: "FK_UserNotifications_AdminNotificationCampaigns_AdminCampaignId",
                table: "UserNotifications",
                column: "AdminCampaignId",
                principalTable: "AdminNotificationCampaigns",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "FK_UserNotifications_Users_CreatedByAdminUserId",
                table: "UserNotifications",
                column: "CreatedByAdminUserId",
                principalTable: "Users",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_UserNotifications_AdminNotificationCampaigns_AdminCampaignId",
                table: "UserNotifications");

            migrationBuilder.DropForeignKey(
                name: "FK_UserNotifications_Users_CreatedByAdminUserId",
                table: "UserNotifications");

            migrationBuilder.DropTable(
                name: "AdminAuditEvents");

            migrationBuilder.DropTable(
                name: "AdminNotificationCampaigns");

            migrationBuilder.DropTable(
                name: "ServerMaintenanceWindows");

            migrationBuilder.DropTable(
                name: "ServerWorkloadCapabilities");

            migrationBuilder.DropIndex(
                name: "IX_UserNotifications_AdminCampaignId",
                table: "UserNotifications");

            migrationBuilder.DropIndex(
                name: "IX_UserNotifications_CreatedByAdminUserId",
                table: "UserNotifications");

            migrationBuilder.DropIndex(
                name: "IX_Servers_FinderEligible",
                table: "Servers");

            migrationBuilder.DropIndex(
                name: "IX_Servers_OperationalStatus",
                table: "Servers");

            migrationBuilder.DropCheckConstraint(
                name: "CK_Servers_CpuCapabilityLevel",
                table: "Servers");

            migrationBuilder.DropCheckConstraint(
                name: "CK_Servers_GpuCapabilityLevel",
                table: "Servers");

            migrationBuilder.DropColumn(
                name: "AdminCampaignId",
                table: "UserNotifications");

            migrationBuilder.DropColumn(
                name: "CreatedByAdminUserId",
                table: "UserNotifications");

            migrationBuilder.DropColumn(
                name: "Message",
                table: "UserNotifications");

            migrationBuilder.DropColumn(
                name: "Source",
                table: "UserNotifications");

            migrationBuilder.DropColumn(
                name: "Title",
                table: "UserNotifications");

            migrationBuilder.DropColumn(
                name: "CpuCapabilityLevel",
                table: "Servers");

            migrationBuilder.DropColumn(
                name: "FinderEligible",
                table: "Servers");

            migrationBuilder.DropColumn(
                name: "GpuCapabilityLevel",
                table: "Servers");

            migrationBuilder.DropColumn(
                name: "OperationalStatus",
                table: "Servers");

            migrationBuilder.DropColumn(
                name: "PerformanceTier",
                table: "Servers");
        }
    }
}
