FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 8080

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY apps/admin-api/ apps/admin-api/
COPY docs/schemas/ docs/schemas/
RUN dotnet restore "apps/admin-api/AdminApi.csproj"
RUN dotnet publish "apps/admin-api/AdminApi.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "AdminApi.dll"]
