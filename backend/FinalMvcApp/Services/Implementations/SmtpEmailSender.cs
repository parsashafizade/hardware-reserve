using FinalMvcApp.Options;
using FinalMvcApp.Services.Interfaces;
using MailKit.Net.Smtp;
using MailKit.Security;
using Microsoft.Extensions.Options;
using MimeKit;

namespace FinalMvcApp.Services.Implementations;

public class SmtpEmailSender : IEmailSender
{
    private readonly SmtpSettings _settings;
    private readonly ILogger<SmtpEmailSender> _logger;

    public SmtpEmailSender(
        IOptions<SmtpSettings> options,
        ILogger<SmtpEmailSender> logger)
    {
        _settings = options.Value;
        _logger = logger;
    }

    public async Task SendPasswordResetCodeAsync(
        string toEmail,
        string fullName,
        string code,
        DateTime expiresAtUtc,
        CancellationToken cancellationToken = default)
    {
        const string subject = "HardwareReserve password reset code";

        var body = $"""
            Hello {fullName},

            Your HardwareReserve password reset code is:

            {code}

            This code expires at {expiresAtUtc:u}.

            If you did not request a password reset,
            you can safely ignore this email.

            HardwareReserve
            """;

        await SendAsync(
            toEmail,
            subject,
            body,
            cancellationToken);
    }

    public async Task SendEmailVerificationCodeAsync(
        string toEmail,
        string fullName,
        string code,
        DateTime expiresAtUtc,
        CancellationToken cancellationToken = default)
    {
        const string subject = "Verify your HardwareReserve email";

        var body = $"""
            Hello {fullName},

            Your HardwareReserve verification code is:

            {code}

            This code expires at {expiresAtUtc:u}.

            If you did not create a HardwareReserve account,
            you can safely ignore this email.

            HardwareReserve
            """;

        await SendAsync(
            toEmail,
            subject,
            body,
            cancellationToken);
    }

    public async Task SendCurrentEmailChangeCodeAsync(
        string toEmail,
        string fullName,
        string code,
        DateTime expiresAtUtc,
        CancellationToken cancellationToken = default)
    {
        const string subject = "Confirm your HardwareReserve email change";

        var body = $"""
            Hello {fullName},

            Use this code to confirm that you requested an email change:

            {code}

            This code expires at {expiresAtUtc:u}.

            If you did not request this change, you can ignore this email.

            HardwareReserve
            """;

        await SendAsync(
            toEmail,
            subject,
            body,
            cancellationToken);
    }

    public async Task SendNewEmailChangeCodeAsync(
        string toEmail,
        string fullName,
        string code,
        DateTime expiresAtUtc,
        CancellationToken cancellationToken = default)
    {
        const string subject = "Verify your new HardwareReserve email";

        var body = $"""
            Hello {fullName},

            Use this code to verify your new email address:

            {code}

            This code expires at {expiresAtUtc:u}.

            If you did not request this change, you can ignore this email.

            HardwareReserve
            """;

        await SendAsync(
            toEmail,
            subject,
            body,
            cancellationToken);
    }

    private async Task SendAsync(
        string toEmail,
        string subject,
        string body,
        CancellationToken cancellationToken)
    {
        var fromEmail = string.IsNullOrWhiteSpace(_settings.FromEmail)
            ? _settings.Username
            : _settings.FromEmail;

        var message = new MimeMessage();

        message.From.Add(
            new MailboxAddress(
                _settings.FromName,
                fromEmail));

        message.To.Add(
            MailboxAddress.Parse(toEmail));

        message.Subject = subject;

        message.Body = new TextPart("plain")
        {
            Text = body
        };

        using var client = new SmtpClient
        {
            CheckCertificateRevocation =
                _settings.CheckCertificateRevocation
        };

        await client.ConnectAsync(
            _settings.Host,
            _settings.Port,
            SecureSocketOptions.StartTls,
            cancellationToken);

        await client.AuthenticateAsync(
            _settings.Username,
            _settings.Password,
            cancellationToken);

        await client.SendAsync(
            message,
            cancellationToken);

        await client.DisconnectAsync(
            true,
            cancellationToken);

        _logger.LogInformation(
            "Email sent successfully to {Email}.",
            toEmail);
    }
}
