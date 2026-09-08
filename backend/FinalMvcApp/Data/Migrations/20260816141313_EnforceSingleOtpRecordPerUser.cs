using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FinalMvcApp.Data.Migrations
{
    /// <inheritdoc />
    public partial class EnforceSingleOtpRecordPerUser : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_PasswordResetCodes_UserId",
                table: "PasswordResetCodes");

            migrationBuilder.DropIndex(
                name: "IX_PasswordResetCodes_UserId_CreatedAt",
                table: "PasswordResetCodes");

            migrationBuilder.DropIndex(
                name: "IX_EmailVerificationCodes_UserId",
                table: "EmailVerificationCodes");

            migrationBuilder.DropIndex(
                name: "IX_EmailVerificationCodes_UserId_CreatedAt",
                table: "EmailVerificationCodes");

            migrationBuilder.Sql(
                """
                WITH ranked_codes AS (
                    SELECT
                        "Id",
                        ROW_NUMBER() OVER (
                            PARTITION BY "UserId"
                            ORDER BY "CreatedAt" DESC, "Id" DESC
                        ) AS row_number
                    FROM "EmailVerificationCodes"
                )
                DELETE FROM "EmailVerificationCodes" AS target
                USING ranked_codes
                WHERE target."Id" = ranked_codes."Id"
                  AND ranked_codes.row_number > 1;
                """);

            migrationBuilder.Sql(
                """
                WITH ranked_codes AS (
                    SELECT
                        "Id",
                        ROW_NUMBER() OVER (
                            PARTITION BY "UserId"
                            ORDER BY "CreatedAt" DESC, "Id" DESC
                        ) AS row_number
                    FROM "PasswordResetCodes"
                )
                DELETE FROM "PasswordResetCodes" AS target
                USING ranked_codes
                WHERE target."Id" = ranked_codes."Id"
                  AND ranked_codes.row_number > 1;
                """);

            migrationBuilder.CreateIndex(
                name: "IX_PasswordResetCodes_UserId",
                table: "PasswordResetCodes",
                column: "UserId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_EmailVerificationCodes_UserId",
                table: "EmailVerificationCodes",
                column: "UserId",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_PasswordResetCodes_UserId",
                table: "PasswordResetCodes");

            migrationBuilder.DropIndex(
                name: "IX_EmailVerificationCodes_UserId",
                table: "EmailVerificationCodes");

            migrationBuilder.CreateIndex(
                name: "IX_PasswordResetCodes_UserId",
                table: "PasswordResetCodes",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_PasswordResetCodes_UserId_CreatedAt",
                table: "PasswordResetCodes",
                columns: new[] { "UserId", "CreatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_EmailVerificationCodes_UserId",
                table: "EmailVerificationCodes",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_EmailVerificationCodes_UserId_CreatedAt",
                table: "EmailVerificationCodes",
                columns: new[] { "UserId", "CreatedAt" });
        }
    }
}
