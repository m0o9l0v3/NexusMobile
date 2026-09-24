FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 8080
RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY apps/admin-api/ apps/admin-api/
COPY docs/schemas/ docs/schemas/
RUN dotnet restore "apps/admin-api/AdminApi.csproj"
RUN dotnet publish "apps/admin-api/AdminApi.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=build /app/publish .
COPY deploy/healthcheck.sh /app/healthcheck
RUN chmod 755 /app/healthcheck
USER $APP_UID
HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD ["/app/healthcheck"]
ENTRYPOINT ["dotnet", "AdminApi.dll"]
