using FinalMvcApp.Models.Entities;
using Microsoft.EntityFrameworkCore;

namespace FinalMvcApp.Data;

public class ApplicationDbContext : DbContext
{
    public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options)
        : base(options)
    {
    }

    public DbSet<User> Users => Set<User>();

    public DbSet<Server> Servers => Set<Server>();

    public DbSet<Reservation> Reservations => Set<Reservation>();

    public DbSet<Payment> Payments => Set<Payment>();

    public DbSet<PasswordResetToken> PasswordResetTokens => Set<PasswordResetToken>();

    public DbSet<EmailVerificationCode> EmailVerificationCodes => Set<EmailVerificationCode>();

    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();

    public DbSet<AnonymousSupportSession> AnonymousSupportSessions => Set<AnonymousSupportSession>();

    public DbSet<SupportConversation> SupportConversations => Set<SupportConversation>();

    public DbSet<SupportConversationReadState> SupportConversationReadStates => Set<SupportConversationReadState>();

    public DbSet<SupportMessage> SupportMessages => Set<SupportMessage>();

    public DbSet<SupportMessageAttachment> SupportMessageAttachments => Set<SupportMessageAttachment>();

    public DbSet<SupportConversationEvent> SupportConversationEvents => Set<SupportConversationEvent>();

    public DbSet<SupportQuickReply> SupportQuickReplies => Set<SupportQuickReply>();

    public DbSet<SupportAiProcessing> SupportAiProcessings => Set<SupportAiProcessing>();

    public DbSet<UserNotification> UserNotifications => Set<UserNotification>();

    public DbSet<ServerWorkloadCapability> ServerWorkloadCapabilities => Set<ServerWorkloadCapability>();

    public DbSet<ServerMaintenanceWindow> ServerMaintenanceWindows => Set<ServerMaintenanceWindow>();

    public DbSet<AdminNotificationCampaign> AdminNotificationCampaigns => Set<AdminNotificationCampaign>();

    public DbSet<AdminAuditEvent> AdminAuditEvents => Set<AdminAuditEvent>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(ApplicationDbContext).Assembly);
    }
    public DbSet<PasswordResetCode> PasswordResetCodes
    => Set<PasswordResetCode>();

    public DbSet<PendingEmailChange> PendingEmailChanges
        => Set<PendingEmailChange>();
}
