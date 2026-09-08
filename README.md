# HardwareReserve (University Project)

HardwareReserve is a full-stack university project for reserving high-performance servers.

- Backend: ASP.NET Core 8 (MVC API style), EF Core, PostgreSQL, JWT, FluentValidation, AutoMapper
- Frontend: React + TypeScript (Vite), React Router, Axios, TailwindCSS
- Architecture: Controllers -> Services -> Repositories -> DbContext

## Tech Stack

- ASP.NET Core 8
- Entity Framework Core 8 + Npgsql
- PostgreSQL
- JWT access token + refresh token
- xUnit (backend tests)
- React 19 + TypeScript
- TailwindCSS

## Core Features

- Public Home and Servers pages (no login required)
- Authentication with simple math captcha
- Role-based access (User/Admin)
- Reservation core logic with overlap prevention
- Smart slot suggestion
- Simulated checkout/payment
- Profile update + profile image upload/crop
- CSV export (user) + Excel export (admin)
- Dashboard stats endpoint (`/dashboard/stats`)
- Persistent user/anonymous/admin support conversations with SignalR delivery
- Optional Gemini support assistant with verified policy and read-only account context

## Project Notes

- This is a university project.
- OTP/SMS/2FA is intentionally removed.
- Docker is intentionally not included.

## Prerequisites

- .NET SDK 8.x
- Node.js 18+
- PostgreSQL 14+

## Backend Setup

1. Configure settings in:

- `backend/FinalMvcApp/appsettings.json`
- `backend/FinalMvcApp/appsettings.Development.json`

Committed config now uses required placeholders. Provide real values via environment variables:

```bash
export ConnectionStrings__DefaultConnection="Host=localhost;Port=5432;Database=finalmvcapp_db;Username=postgres;Password=postgres"
export Jwt__Secret="xHX9dXYN7Xid0V7u0/aYe320vcGV0fS0skXoPlF/pttRZ7LiWqWYte+DAbHdLctR"
```

Production deployments also require the licensed AutoMapper package key used by the secured dependency version:

```bash
export AutoMapper__LicenseKey="YOUR_AUTOMAPPER_LICENSE_KEY"
```

Development and automated tests may run without this key. Production fails fast when it is absent instead of silently running an unlicensed dependency.

Optional:

```bash
export Jwt__Issuer="FinalMvcApp"
export Jwt__Audience="FinalMvcAppClient"
export Jwt__AccessTokenMinutes="30"
export Jwt__RefreshTokenDays="7"
```

Enable Gemini support only from the backend:

```bash
export SupportAI__Enabled="true"
export Gemini__ApiKey="    "
export Gemini__Model="gemini-3.6-flash"
```

`Gemini__ApiKey` is required when `SupportAI__Enabled=true`. The committed files contain only a placeholder. When AI support is disabled or the provider becomes unavailable, user messages remain persisted and the conversation is safely handed to human support.

2. Restore and build:

```bash
dotnet restore FinalMvcSolution.sln
dotnet build FinalMvcSolution.sln
```

3. Apply migrations:

```bash
# If dotnet-ef is installed globally:
dotnet ef database update --project backend/FinalMvcApp --startup-project backend/FinalMvcApp

# If you use the local tool manifest:
dotnet tool run dotnet-ef database update --project backend/FinalMvcApp --startup-project backend/FinalMvcApp
```

4. Run backend:

```bash
dotnet run --project backend/FinalMvcApp
```

Quick backend command sequence:

```bash
dotnet restore FinalMvcSolution.sln
dotnet ef database update --project backend/FinalMvcApp --startup-project backend/FinalMvcApp
dotnet run --project backend/FinalMvcApp
```

Swagger:

- [https://localhost:7138/swagger](https://localhost:7138/swagger)
- HTTP: `http://localhost:5239`

## Frontend Setup

1. Go to frontend folder:

```bash
cd frontend
```

2. Install dependencies:

```bash
npm install
```

3. Configure `.env` (or copy from `.env.example`):

```env
VITE_API_BASE_URL=http://localhost:5239
```

4. Run frontend:

```bash
npm run dev
```

Open: [http://localhost:5173](http://localhost:5173)

## Default Seed Data

Seeded automatically at startup:

- Admin user:
  - Identifier: `admin`
  - Password: `1234`
  - Role: `Admin`
- Demo user:
  - Email: `demo@university.local`
  - Password: `1234`
  - Role: `User`
- Exactly 15 active servers for products catalog

## Captcha (Simple Math)

For login/register:

1. Call `GET /auth/captcha`
2. Backend returns `{ captchaId, a, b }`
3. Send `captchaId` and `captchaAnswer = a + b` in login/register request

Captcha is short-lived and single-use.

## Important Routes

Public:

- `/`
- `/servers`
- `/server/:id`

Auth:

- `/login`
- `/register`
- `/forgot-password`
- `/reset-password`

Protected:

- `/profile`
- `/my-reservations`
- `/my-services`
- `/reserve/:serverId`
- `/checkout/:reservationId`

Admin:

- `/admin`
- `/admin/servers`
- `/admin/orders`
- `/admin/users`

Support API:

- Authenticated user: `/support/conversations`
- Anonymous session and conversations: `/support/anonymous`
- Admin inbox operations: `/admin/support/conversations`
- Admin-only AI draft: `POST /admin/support/conversations/{conversationId}/suggest-reply`
- Authenticated realtime hub: `/hubs/support`

## Swagger Usage Example

1. `GET /auth/captcha`
2. `POST /auth/login` with captcha fields
3. Copy `accessToken`
4. Click **Authorize** in Swagger and set `Bearer <accessToken>`
5. Test protected/admin endpoints

Example login payload:

```json
{
  "identifier": "admin",
  "password": "1234",
  "captchaId": "<captcha_id>",
  "captchaAnswer": 10
}
```

## Testing

Run backend tests:

```bash
dotnet test FinalMvcSolution.sln
```

Included xUnit tests cover:

- Reservation overlap prevention
- Pricing calculation logic
- Captcha expiration and single-use behavior
- Refresh token rotation logic
- Support ownership, lifecycle, unread state, idempotency, and pagination
- AI scope/policy enforcement, Persian/English/mixed text, safe account context, escalation, resolution, provisioning windows, title fallback, provider failure, and duplicate processing

## Export Endpoints

- User CSV export: `GET /export/csv`
- Admin Excel export: `GET /admin/export/excel`

Both are wired in frontend and return downloadable files.

## Error Response Shape

```json
{
  "traceId": "...",
  "message": "...",
  "errors": {
    "field": ["error"]
  }
}
```
