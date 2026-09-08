using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FinalMvcApp.Data.Migrations
{
    /// <inheritdoc />
    public partial class Phase1LifecycleNotificationReliability : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "CompletedNotificationDelivered",
                table: "Reservations",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "StartedNotificationDelivered",
                table: "Reservations",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            // Preserve the existing product's one-day completion reconciliation
            // without sending stale lifecycle events for old reservations when
            // these durable delivery markers are first deployed.
            migrationBuilder.Sql(
                """
                UPDATE "Reservations" AS r
                SET "StartedNotificationDelivered" = TRUE
                WHERE r."Status" = 'Paid'
                  AND (
                    r."EndTime" <= NOW()
                    OR EXISTS (
                      SELECT 1
                      FROM "UserNotifications" AS n
                      WHERE n."ReservationId" = r."Id"
                        AND n."Type" = 'ReservationStarted'
                    )
                  )
                """);

            migrationBuilder.Sql(
                """
                UPDATE "Reservations" AS r
                SET "CompletedNotificationDelivered" = TRUE
                WHERE r."Status" = 'Paid'
                  AND (
                    r."EndTime" < NOW() - INTERVAL '1 day'
                    OR EXISTS (
                      SELECT 1
                      FROM "UserNotifications" AS n
                      WHERE n."ReservationId" = r."Id"
                        AND n."Type" = 'ReservationCompleted'
                    )
                  )
                """);

            migrationBuilder.CreateIndex(
                name: "IX_Reservations_PendingCompletedNotification",
                table: "Reservations",
                column: "EndTime",
                filter: "\"Status\" = 'Paid' AND NOT \"CompletedNotificationDelivered\"");

            migrationBuilder.CreateIndex(
                name: "IX_Reservations_PendingStartedNotification",
                table: "Reservations",
                column: "StartTime",
                filter: "\"Status\" = 'Paid' AND NOT \"StartedNotificationDelivered\"");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Reservations_PendingCompletedNotification",
                table: "Reservations");

            migrationBuilder.DropIndex(
                name: "IX_Reservations_PendingStartedNotification",
                table: "Reservations");

            migrationBuilder.DropColumn(
                name: "CompletedNotificationDelivered",
                table: "Reservations");

            migrationBuilder.DropColumn(
                name: "StartedNotificationDelivered",
                table: "Reservations");
        }
    }
}
