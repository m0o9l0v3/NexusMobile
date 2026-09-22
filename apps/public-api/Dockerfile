FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 8080

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY apps/public-api/ apps/public-api/
COPY apps/admin-api/ apps/admin-api/
COPY docs/schemas/ docs/schemas/
RUN dotnet restore "apps/public-api/PublicApi.csproj"
RUN dotnet publish "apps/public-api/PublicApi.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "PublicApi.dll"]
