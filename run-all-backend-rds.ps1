# Run ALL backend services against the AWS RDS PostgreSQL database (ggfixservice).
#
# This points every service at the cloud RDS instance instead of local Postgres.
# Services use ddl-auto: validate, so the RDS schema must already match the
# entities (it currently has the full 70-table schema).
#
# SSL: RDS accepts TLS. We override the JDBC URL via SPRING_DATASOURCE_URL so we
# can append ?sslmode=require (encrypt in transit, no client-side cert file needed).
#
# Run from the backend root:
#     .\run-all-backend-rds.ps1

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$svc = "$root\services"

if (-not (Get-Command mvn -ErrorAction SilentlyContinue)) {
    Write-Host "Maven (mvn) not found on PATH." -ForegroundColor Yellow
    exit 1
}

# ---- RDS connection settings ----
$RdsHost = "ggfixservice.cdaiqaog82ho.ap-south-1.rds.amazonaws.com"
$RdsPort = "5432"
$RdsDb   = "ggfixservice"
$RdsUser = "postgres"
$RdsPass = "Globogreen1254"
$JdbcUrl = "jdbc:postgresql://${RdsHost}:${RdsPort}/${RdsDb}?sslmode=require"

$services = @(
    @{ Name = "Auth";         Dir = "auth-service";         Port = 8081 },
    @{ Name = "Master Data";  Dir = "master-data-service";  Port = 8091 },
    @{ Name = "Ticket";       Dir = "ticket-service";       Port = 8082 },
    @{ Name = "User";         Dir = "user-service";         Port = 8083 },
    @{ Name = "Shop";         Dir = "shop-service";         Port = 8084 },
    @{ Name = "Technician";   Dir = "technician-service";   Port = 8085 },
    @{ Name = "Inventory";    Dir = "inventory-service";    Port = 8086 },
    @{ Name = "Marketplace";  Dir = "marketplace-service";  Port = 8087 },
    @{ Name = "Pickup";       Dir = "pickup-service";       Port = 8088 },
    @{ Name = "Notification"; Dir = "notification-service"; Port = 8089 },
    @{ Name = "Subscription"; Dir = "subscription-service"; Port = 8090 },
    @{ Name = "Order";        Dir = "order-service";        Port = 8092 }
)

foreach ($s in $services) {
    $dir = Join-Path $svc $s.Dir
    if (-not (Test-Path $dir)) { Write-Host "Skip $($s.Name) (not found: $dir)" -ForegroundColor Yellow; continue }
    Write-Host "Starting $($s.Name) (port $($s.Port)) on RDS..."
    $cmd = "`$Host.UI.RawUI.WindowTitle = 'ggfix-$($s.Name)-$($s.Port)-RDS';" +
           "`$env:SPRING_DATASOURCE_URL='$JdbcUrl';" +
           "`$env:DB_USER='$RdsUser';" +
           "`$env:DB_PASSWORD='$RdsPass';" +
           "cd '$dir'; mvn -q -DskipTests spring-boot:run"
    Start-Process powershell -ArgumentList @("-NoExit","-Command",$cmd) | Out-Null
    Start-Sleep -Seconds 2
}

Write-Host ""
Write-Host "All services starting against RDS ($RdsHost / db=$RdsDb)." -ForegroundColor Green
Write-Host "Wait until each window prints 'Started ...Application'." -ForegroundColor Green
