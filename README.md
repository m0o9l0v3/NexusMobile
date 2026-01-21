# Nexus Admin Platform (MVP)

This repository contains the admin management portal and admin API for Nexus.

## Monorepo Structure
```
/apps
  /admin-web          React Admin Portal (Vite + TypeScript + MUI)
  /admin-api          ASP.NET Core Admin API (.NET 8)
/packages
  /openapi            OpenAPI specifications
/docs                 Operational notes
/docker               Docker compose for local dev
```

## Requirements
- Node.js 20+
- .NET 8 SDK
- Docker (optional for PostgreSQL)

## Local Development

### Dockerなしで開発（SQLite）
1) Admin API を起動
```bash
cd apps/admin-api
$env:ASPNETCORE_ENVIRONMENT="Development"
dotnet run
```

2) Admin Portal を起動
```bash
cd apps/admin-web
npm install
npm run dev
```

SQLite の開発用 DB は `apps/admin-api/admin-dev.db` に作成されます。

### 1) Start PostgreSQL + Admin API (Docker)
```bash
cd docker
docker-compose up --build
```

The API will be available at `http://localhost:5000`.
Swagger UI is available at `http://localhost:5000/swagger` in Development.

### 2) Start Admin Portal
```bash
cd apps/admin-web
npm install
npm run dev
```

Open `http://localhost:5173`.

### 3) Environment Variables
Copy `.env.example` to `.env` and adjust:
- `VITE_ADMIN_API_BASE_URL`
- `VITE_PARTICIPANT_BASE_URL`

### 4) Login
Default credentials (change in production):
- Username: `admin`
- Password: `AdminPassword123!`

## Database & Migrations
The API applies EF Core migrations on startup and seeds sample data for Spots, Events, and OcDays.

If you need to apply migrations manually:
```bash
cd apps/admin-api
# dotnet ef database update
```

## OpenAPI Policy
The Admin API OpenAPI spec is stored in `/packages/openapi/admin.yaml` and is the source of truth.

To export the YAML from Swagger:
```bash
dotnet tool install --global Swashbuckle.AspNetCore.Cli
swagger tofile --yaml ./apps/admin-api/bin/Debug/net8.0/AdminApi.dll v1 > ./packages/openapi/admin.yaml
```

## API Features (MVP)
- Admin login (JWT)
- CRUD for Spots, Events, OcDays
- Publish state toggle
- QR code PNG generation for spot URLs
- Recent logs list (last 100)

## Future Notes
- Reserve Spot fields for 3D/AR (content assets, model reference).
- Log aggregation and analytics are postponed.
