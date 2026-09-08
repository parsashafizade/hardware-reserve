using FinalMvcApp.Data;
using FinalMvcApp.Data.Seed;
using FinalMvcApp.DTOs.Common;
using FinalMvcApp.Hubs;
using FinalMvcApp.Mappings;
using FinalMvcApp.Middleware;
using FinalMvcApp.Options;
using FinalMvcApp.Repositories.Implementations;
using FinalMvcApp.Repositories.Interfaces;
using FinalMvcApp.Services.Implementations;
using FinalMvcApp.Services.Interfaces;
using FinalMvcApp.Swagger;
using FinalMvcApp.Validation.Auth;
using FluentValidation;
using FluentValidation.AspNetCore;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using System.Security.Claims;
using System.Text;
using System.Threading.RateLimiting;
using FinalMvcApp.Errors;

var builder = WebApplication.CreateBuilder(args);
const string RequiredPlaceholder = "__REQUIRED__";

builder.Logging.ClearProviders();
builder.Logging.AddConsole();
builder.Logging.AddDebug();


// ---------------------------------------------------------
// Configuration
// ---------------------------------------------------------

var jwtSection =
    builder.Configuration.GetSection(JwtSettings.SectionName);

builder.Services.Configure<JwtSettings>(jwtSection);

var jwtSettings = jwtSection.Get<JwtSettings>()
    ?? throw new InvalidOperationException("JWT settings are missing.");


var smtpSection =
    builder.Configuration.GetSection(SmtpSettings.SectionName);

builder.Services.Configure<SmtpSettings>(smtpSection);

var smtpSettings =
    smtpSection.Get<SmtpSettings>() ?? new SmtpSettings();


var emailVerificationSection =
    builder.Configuration.GetSection(
        EmailVerificationSettings.SectionName);

builder.Services.Configure<EmailVerificationSettings>(
    emailVerificationSection);


var passwordResetSection =
    builder.Configuration.GetSection(
        PasswordResetSettings.SectionName);

builder.Services.Configure<PasswordResetSettings>(
    passwordResetSection);


var corsOrigins =
    builder.Configuration
        .GetSection("Cors:AllowedOrigins")
        .Get<string[]>()
    ?? ["http://localhost:5173"];


var supportAiSection =
    builder.Configuration.GetSection(
        SupportAiOptions.SectionName);

var geminiSection =
    builder.Configuration.GetSection(
        GeminiOptions.SectionName);

builder.Services.Configure<SupportAiOptions>(
    supportAiSection);

builder.Services.Configure<GeminiOptions>(
    geminiSection);

var supportAiOptions =
    supportAiSection.Get<SupportAiOptions>()
    ?? new SupportAiOptions();

var geminiOptions =
    geminiSection.Get<GeminiOptions>()
    ?? new GeminiOptions();


var autoMapperLicenseKey =
    builder.Configuration["AutoMapper:LicenseKey"];

var hasAutoMapperLicense =
    !string.IsNullOrWhiteSpace(autoMapperLicenseKey)
    && !string.Equals(
        autoMapperLicenseKey,
        RequiredPlaceholder,
        StringComparison.OrdinalIgnoreCase);


// ---------------------------------------------------------
// Configuration validation
// ---------------------------------------------------------

if (builder.Environment.IsProduction()
    && !hasAutoMapperLicense)
{
    throw new InvalidOperationException(
        "AutoMapper license key is required in Production. Configure environment variable 'AutoMapper__LicenseKey'.");
}


if (string.IsNullOrWhiteSpace(jwtSettings.Secret)
    || string.Equals(
        jwtSettings.Secret,
        RequiredPlaceholder,
        StringComparison.OrdinalIgnoreCase))
{
    throw new InvalidOperationException(
        "JWT secret is required. Configure 'Jwt:Secret' (or environment variable 'Jwt__Secret').");
}

if (jwtSettings.Secret.Length < 32)
{
    throw new InvalidOperationException(
        "JWT secret must be at least 32 characters.");
}


if (string.IsNullOrWhiteSpace(smtpSettings.Username)
    || string.Equals(
        smtpSettings.Username,
        RequiredPlaceholder,
        StringComparison.OrdinalIgnoreCase))
{
    throw new InvalidOperationException(
        "SMTP username is required. Configure environment variable 'Smtp__Username'.");
}

if (string.IsNullOrWhiteSpace(smtpSettings.Password)
    || string.Equals(
        smtpSettings.Password,
        RequiredPlaceholder,
        StringComparison.OrdinalIgnoreCase))
{
    throw new InvalidOperationException(
        "SMTP App Password is required. Configure environment variable 'Smtp__Password'.");
}

if (string.IsNullOrWhiteSpace(smtpSettings.Host))
{
    throw new InvalidOperationException(
        "SMTP host is required.");
}

if (smtpSettings.Port is < 1 or > 65535)
{
    throw new InvalidOperationException(
        "SMTP port is invalid.");
}


if (supportAiOptions.TimeoutSeconds is < 1 or > 120
    || supportAiOptions.MaxRetries is < 0 or > 3
    || supportAiOptions.MaxContextMessages is < 1 or > 100
    || supportAiOptions.MaxContextCharacters is < 1000 or > 100000
    || supportAiOptions.MaxOutputTokens is < 256 or > 8192
    || supportAiOptions.MinimumConfidence is < 0 or > 1
    || supportAiOptions.ProcessingLeaseSeconds is < 10 or > 1200)
{
    throw new InvalidOperationException(
        "SupportAI configuration contains values outside the supported bounds.");
}

if (supportAiOptions.ProcessingLeaseSeconds
    < supportAiOptions.MinimumProcessingLeaseSeconds)
{
    throw new InvalidOperationException(
        $"SupportAI:ProcessingLeaseSeconds must be at least {supportAiOptions.MinimumProcessingLeaseSeconds} " +
        "for the configured timeout and retry limits.");
}


if (supportAiOptions.Enabled)
{
    if (!string.Equals(
        supportAiOptions.Provider,
        "Gemini",
        StringComparison.OrdinalIgnoreCase))
    {
        throw new InvalidOperationException(
            "SupportAI:Provider must be 'Gemini'.");
    }

    if (string.IsNullOrWhiteSpace(geminiOptions.ApiKey)
        || string.Equals(
            geminiOptions.ApiKey,
            RequiredPlaceholder,
            StringComparison.OrdinalIgnoreCase))
    {
        throw new InvalidOperationException(
            "Gemini API key is required when SupportAI is enabled. Configure environment variable 'Gemini__ApiKey'.");
    }

    if (string.IsNullOrWhiteSpace(geminiOptions.Model))
    {
        throw new InvalidOperationException(
            "Gemini:Model is required when SupportAI is enabled.");
    }

    if (!Uri.TryCreate(
            geminiOptions.BaseUrl,
            UriKind.Absolute,
            out var geminiBaseUri)
        || geminiBaseUri.Scheme != Uri.UriSchemeHttps)
    {
        throw new InvalidOperationException(
            "Gemini:BaseUrl must be an absolute HTTPS URL.");
    }
}


// ---------------------------------------------------------
// ASP.NET Core
// ---------------------------------------------------------

builder.Services.AddControllersWithViews();
builder.Services.AddProblemDetails();
builder.Services.AddMemoryCache();

builder.Services.AddSignalR(
    options =>
        options.MaximumReceiveMessageSize = 16 * 1024);


// ---------------------------------------------------------
// CORS
// ---------------------------------------------------------

builder.Services.AddCors(options =>
{
    options.AddPolicy("Frontend", policy =>
    {
        policy
            .WithOrigins(corsOrigins)
            .AllowAnyHeader()
            .AllowAnyMethod()
            .AllowCredentials();
    });
});


// ---------------------------------------------------------
// Rate limiting
// ---------------------------------------------------------

builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode =
        StatusCodes.Status429TooManyRequests;

    options.OnRejected =
        async (context, cancellationToken) =>
        {
            context.HttpContext.Response.ContentType =
                "application/json";

            await context.HttpContext.Response.WriteAsJsonAsync(
                    new ErrorResponseDto
                    {
                        TraceId = context.HttpContext.TraceIdentifier,
                        Code = ApiErrorCodes.TooManyRequests,
                        Message = "Too many requests. Please try again shortly."
                    },
                cancellationToken);
        };
    options.AddPolicy(AuthRateLimitPolicies.Authentication, httpContext =>
        {
            var remoteIp =
                httpContext.Connection.RemoteIpAddress?.ToString()
                ?? "unknown";

            return RateLimitPartition.GetFixedWindowLimiter(
                $"auth:{remoteIp}",
                _ => new FixedWindowRateLimiterOptions
                {
                    PermitLimit = 10,
                    Window = TimeSpan.FromMinutes(1),
                    QueueLimit = 0,
                    AutoReplenishment = true
                });
        });

    options.AddPolicy(AuthRateLimitPolicies.CodeSend, httpContext =>
        {
            var remoteIp =
                httpContext.Connection.RemoteIpAddress?.ToString()
                ?? "unknown";

            return RateLimitPartition.GetFixedWindowLimiter(
                $"auth-code-send:{remoteIp}",
                _ => new FixedWindowRateLimiterOptions
                {
                    PermitLimit = 5,
                    Window = TimeSpan.FromMinutes(10),
                    QueueLimit = 0,
                    AutoReplenishment = true
                });
        });

    options.AddPolicy(AuthRateLimitPolicies.CodeVerify, httpContext =>
        {
            var remoteIp =
                httpContext.Connection.RemoteIpAddress?.ToString()
                ?? "unknown";

            return RateLimitPartition.GetFixedWindowLimiter(
                $"auth-code-verify:{remoteIp}",
                _ => new FixedWindowRateLimiterOptions
                {
                    PermitLimit = 15,
                    Window = TimeSpan.FromMinutes(5),
                    QueueLimit = 0,
                    AutoReplenishment = true
                });
        });


    options.AddPolicy(
        SupportRateLimitPolicies.Standard,
        httpContext =>
        {
            var userId =
                httpContext.User.FindFirstValue(
                    ClaimTypes.NameIdentifier);

            var remoteIp =
                httpContext.Connection
                    .RemoteIpAddress?
                    .ToString()
                ?? "unknown";

            var partitionKey =
                !string.IsNullOrWhiteSpace(userId)
                    ? $"user:{userId}"
                    : $"ip:{remoteIp}";

            return RateLimitPartition
                .GetFixedWindowLimiter(
                    partitionKey,
                    _ => new FixedWindowRateLimiterOptions
                    {
                        PermitLimit = 60,
                        Window =
                            TimeSpan.FromMinutes(1),
                        QueueLimit = 0,
                        AutoReplenishment = true
                    });
        });


    options.AddPolicy(
        SupportRateLimitPolicies.Message,
        httpContext =>
        {
            var userId =
                httpContext.User.FindFirstValue(
                    ClaimTypes.NameIdentifier);

            var remoteIp =
                httpContext.Connection
                    .RemoteIpAddress?
                    .ToString()
                ?? "unknown";

            var partitionKey =
                !string.IsNullOrWhiteSpace(userId)
                    ? $"message:user:{userId}"
                    : $"message:ip:{remoteIp}";

            return RateLimitPartition
                .GetFixedWindowLimiter(
                    partitionKey,
                    _ => new FixedWindowRateLimiterOptions
                    {
                        PermitLimit = 12,
                        Window =
                            TimeSpan.FromMinutes(1),
                        QueueLimit = 0,
                        AutoReplenishment = true
                    });
        });
});


// ---------------------------------------------------------
// Validation
// ---------------------------------------------------------

builder.Services.Configure<ApiBehaviorOptions>(
    options =>
    {
        options.InvalidModelStateResponseFactory =
            context =>
            {
                var errors =
                    context.ModelState
                        .Where(
                            entry =>
                                entry.Value?
                                    .Errors.Count > 0)
                        .ToDictionary(
                            entry => entry.Key,
                            entry =>
                                entry.Value!
                                    .Errors
                                    .Select(
                                        error =>
                                            error.ErrorMessage)
                                    .ToArray());

                var payload =
                    new ErrorResponseDto
                    {
                        TraceId =
                            context.HttpContext
                                .TraceIdentifier,
                        Message =
                            "Validation failed.",
                        Errors = errors
                    };

                return new BadRequestObjectResult(
                    payload);
            };
    });

builder.Services.AddFluentValidationAutoValidation();
builder.Services.AddFluentValidationClientsideAdapters();

builder.Services.AddValidatorsFromAssemblyContaining<
    RegisterRequestDtoValidator>();


// ---------------------------------------------------------
// AutoMapper
// ---------------------------------------------------------

builder.Services.AddAutoMapper(
    configuration =>
    {
        if (hasAutoMapperLicense)
        {
            configuration.LicenseKey =
                autoMapperLicenseKey;
        }
    },
    typeof(MappingProfile).Assembly);


// ---------------------------------------------------------
// Database
// ---------------------------------------------------------

var connectionString =
    builder.Configuration
        .GetConnectionString("DefaultConnection")
    ?? throw new InvalidOperationException(
        "Connection string 'DefaultConnection' was not found.");

if (string.IsNullOrWhiteSpace(connectionString)
    || string.Equals(
        connectionString,
        RequiredPlaceholder,
        StringComparison.OrdinalIgnoreCase))
{
    throw new InvalidOperationException(
        "Database connection string is required. Configure 'ConnectionStrings:DefaultConnection' (or environment variable 'ConnectionStrings__DefaultConnection').");
}

builder.Services.AddDbContext<ApplicationDbContext>(
    options =>
        options.UseNpgsql(connectionString));


// ---------------------------------------------------------
// Repositories
// ---------------------------------------------------------

builder.Services.AddScoped(
    typeof(IRepository<>),
    typeof(Repository<>));

builder.Services.AddScoped<
    IUserRepository,
    UserRepository>();

builder.Services.AddScoped<
    IServerRepository,
    ServerRepository>();

builder.Services.AddScoped<
    IReservationRepository,
    ReservationRepository>();

builder.Services.AddScoped<
    IPaymentRepository,
    PaymentRepository>();

builder.Services.AddScoped<
    IPasswordResetTokenRepository,
    PasswordResetTokenRepository>();

builder.Services.AddScoped<
    IPasswordResetCodeRepository,
    PasswordResetCodeRepository>();

builder.Services.AddScoped<
    IRefreshTokenRepository,
    RefreshTokenRepository>();

builder.Services.AddScoped<
    IEmailVerificationCodeRepository,
    EmailVerificationCodeRepository>();

builder.Services.AddScoped<
    IPendingEmailChangeRepository,
    PendingEmailChangeRepository>();

builder.Services.AddScoped<
    ISupportRepository,
    SupportRepository>();

builder.Services.AddScoped<
    ISupportQuickReplyRepository,
    SupportQuickReplyRepository>();

builder.Services.AddScoped<
    IUserNotificationRepository,
    UserNotificationRepository>();

builder.Services.AddScoped<
    IAdminControlRepository,
    AdminControlRepository>();


// ---------------------------------------------------------
// Support / infrastructure
// ---------------------------------------------------------

builder.Services.AddSingleton(TimeProvider.System);

builder.Services.AddSingleton<
    ISupportKnowledgeSource,
    SupportKnowledgeSource>();

builder.Services.AddScoped<
    ISupportAccountContextService,
    SupportAccountContextService>();

builder.Services.AddScoped<
    ISupportAiPolicyService,
    SupportAiPolicyService>();

builder.Services.AddTransient<
    DisabledSupportAiProvider>();

builder.Services.AddHttpClient<
    GeminiSupportAiProvider>(
    client =>
    {
        client.BaseAddress =
            new Uri(
                geminiOptions.BaseUrl,
                UriKind.Absolute);

        client.Timeout =
            Timeout.InfiniteTimeSpan;
    });

builder.Services.AddScoped<
    ISupportAiProvider>(
    serviceProvider =>
        supportAiOptions.Enabled
            ? serviceProvider
                .GetRequiredService<
                    GeminiSupportAiProvider>()
            : serviceProvider
                .GetRequiredService<
                    DisabledSupportAiProvider>());


// ---------------------------------------------------------
// Services
// ---------------------------------------------------------

builder.Services.AddScoped<
    IPasswordHasher,
    BCryptPasswordHasher>();

builder.Services.AddScoped<
    IServerService,
    ServerService>();

builder.Services.AddScoped<
    IReservationService,
    ReservationService>();

builder.Services.AddScoped<
    IDashboardService,
    DashboardService>();

builder.Services.AddScoped<
    IPaymentService,
    PaymentService>();

builder.Services.AddScoped<
    ICaptchaService,
    MathCaptchaService>();

builder.Services.AddScoped<
    IJwtTokenService,
    JwtTokenService>();

builder.Services.AddScoped<
    IEmailSender,
    SmtpEmailSender>();

builder.Services.AddScoped<
    IEmailVerificationService,
    EmailVerificationService>();

builder.Services.AddScoped<
    IPasswordResetCodeService,
    PasswordResetCodeService>();

builder.Services.AddScoped<
    IAuthService,
    AuthService>();

builder.Services.AddScoped<
    IEmailChangeService,
    EmailChangeService>();

builder.Services.AddScoped<
    IProfileService,
    ProfileService>();

builder.Services.AddScoped<
    IAdminService,
    AdminService>();

builder.Services.AddScoped<
    IAdminControlService,
    AdminControlService>();

builder.Services.AddScoped<
    ISupportRealtimeNotifier,
    SupportRealtimeNotifier>();

builder.Services.AddScoped<
    ISupportAiOrchestrator,
    SupportAiOrchestrator>();

builder.Services.AddScoped<
    ISupportService,
    SupportService>();

builder.Services.AddScoped<
    IAdminSupportService,
    AdminSupportService>();

builder.Services.AddScoped<
    IUserNotificationRealtimeNotifier,
    UserNotificationRealtimeNotifier>();

builder.Services.AddScoped<
    IUserNotificationService,
    UserNotificationService>();

builder.Services.AddScoped<
    IServiceDetailsNotificationService,
    ServiceDetailsNotificationService>();

builder.Services.AddScoped<
    IReservationReminderService,
    ReservationReminderService>();

builder.Services.AddHostedService<
    ReservationNotificationWorker>();


// ---------------------------------------------------------
// Authentication
// ---------------------------------------------------------

builder.Services
    .AddAuthentication(
        JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters =
            new TokenValidationParameters
            {
                ValidateIssuer = true,
                ValidateAudience = true,
                ValidateIssuerSigningKey = true,
                ValidateLifetime = true,

                ValidIssuer =
                    jwtSettings.Issuer,

                ValidAudience =
                    jwtSettings.Audience,

                IssuerSigningKey =
                    new SymmetricSecurityKey(
                        Encoding.UTF8.GetBytes(
                            jwtSettings.Secret)),

                RoleClaimType =
                    ClaimTypes.Role,

                NameClaimType =
                    ClaimTypes.NameIdentifier,

                ClockSkew =
                    TimeSpan.Zero
            };

        options.Events =
            new JwtBearerEvents
            {
                OnMessageReceived =
                    context =>
                    {
                        var accessToken =
                            context.Request.Query[
                                "access_token"];

                        if (!string.IsNullOrWhiteSpace(
                                accessToken)
                            && context.HttpContext
                                .Request.Path
                                .StartsWithSegments(
                                    "/hubs/support"))
                        {
                            context.Token =
                                accessToken;
                        }

                        return Task.CompletedTask;
                    },

                OnChallenge =
                    async context =>
                    {
                        context.HandleResponse();
                        if (context.Response.HasStarted)
                        {
                            return;
                        }

                        context.Response.StatusCode =
                            StatusCodes.Status401Unauthorized;

                        await context.Response.WriteAsJsonAsync(
                            new ErrorResponseDto
                            {
                                TraceId = context.HttpContext.TraceIdentifier,
                                Code = ApiErrorCodes.AuthenticationRequired,
                                Message = "Authentication is required."
                            });
                    },

                OnForbidden =
                    async context =>
                    {
                        if (context.Response.HasStarted)
                        {
                            return;
                        }

                        context.Response.StatusCode =
                            StatusCodes.Status403Forbidden;

                        await context.Response.WriteAsJsonAsync(
                            new ErrorResponseDto
                            {
                                TraceId = context.HttpContext.TraceIdentifier,
                                Code = ApiErrorCodes.Forbidden,
                                Message = "You are not authorized to perform this action."
                            });
                    }
            };
    });

builder.Services.AddAuthorization();


// ---------------------------------------------------------
// Swagger
// ---------------------------------------------------------

builder.Services.AddEndpointsApiExplorer();

builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc(
        "v1",
        new OpenApiInfo
        {
            Title = "FinalMvcApp API",
            Version = "v1"
        });

    var securityScheme =
        new OpenApiSecurityScheme
        {
            Name = "Authorization",
            Description =
                "Enter: Bearer {your JWT token}",
            In = ParameterLocation.Header,
            Type =
                SecuritySchemeType.Http,
            Scheme = "bearer",
            BearerFormat = "JWT",

            Reference =
                new OpenApiReference
                {
                    Type =
                        ReferenceType.SecurityScheme,
                    Id =
                        JwtBearerDefaults
                            .AuthenticationScheme
                }
        };

    options.AddSecurityDefinition(
        JwtBearerDefaults.AuthenticationScheme,
        securityScheme);

    options.AddSecurityRequirement(
        new OpenApiSecurityRequirement
        {
            {
                securityScheme,
                Array.Empty<string>()
            }
        });

    options.OperationFilter<
        FileUploadOperationFilter>();
});


// ---------------------------------------------------------
// Application
// ---------------------------------------------------------

var app = builder.Build();


// ---------------------------------------------------------
// Database migrations & seed
// ---------------------------------------------------------

using (var scope =
       app.Services.CreateScope())
{
    var dbContext =
        scope.ServiceProvider
            .GetRequiredService<
                ApplicationDbContext>();

    await dbContext.Database.MigrateAsync();

    if (app.Environment.IsDevelopment())
    {
        await AdminSeeder.SeedAsync(
            dbContext);

        await DemoUserSeeder.SeedAsync(
            dbContext);

        await ServerSeeder.SeedAsync(
            dbContext);
    }
}


// ---------------------------------------------------------
// Middleware
// ---------------------------------------------------------

app.UseMiddleware<
    GlobalExceptionHandlingMiddleware>();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}
else
{
    app.UseExceptionHandler(
        "/Home/Error");

    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();

app.UseRouting();

app.UseCors("Frontend");

app.UseAuthentication();
app.UseRateLimiter();
app.UseAuthorization();


// ---------------------------------------------------------
// Endpoints
// ---------------------------------------------------------

app.MapControllers();

app.MapHub<SupportHub>(
        "/hubs/support",
        options =>
            options.CloseOnAuthenticationExpiration =
                true)
    .RequireRateLimiting(
        SupportRateLimitPolicies.Standard);

app.MapControllerRoute(
    name: "default",
    pattern:
        "{controller=Home}/{action=Index}/{id?}");

app.Run();
