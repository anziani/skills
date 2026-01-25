<#
.SYNOPSIS
    Service Fabric cluster management and troubleshooting script.

.DESCRIPTION
    Provides commands for deploying, managing, and troubleshooting Service Fabric
    applications on local and remote clusters.

.PARAMETER Command
    The command to execute. Available commands:
    
    Deployment:
      deploy          - Build and deploy an application to a cluster
      build           - Build application package only
      remove          - Remove application from cluster
    
    Cluster Info:
      apps            - List all deployed applications
      services        - List services in an application
      health          - Get health status of application/service
      nodes           - List cluster nodes
      cluster-health  - Get overall cluster health
    
    Troubleshooting:
      logs            - View application logs
      logs-watch      - Watch logs in real-time
      logs-errors     - Search for errors in logs
      events          - View Windows Event Log entries
      sf-events       - View Service Fabric events
    
    Database:
      db-list         - List Sonar databases
      db-tables       - List tables in a database
      db-schema       - Get table schema
      db-query        - Execute a SQL query
      db-procs        - List stored procedures
      db-proc-code    - View stored procedure code
    
    Configuration:
      config          - View service configuration

.PARAMETER ApplicationName
    Name of the SF application (e.g., SonarCoreApplication)

.PARAMETER ServiceName
    Name of the service within an application (e.g., QueueService)

.PARAMETER Database
    Database name for database commands

.PARAMETER Table
    Table name for schema/query commands

.PARAMETER Query
    SQL query to execute

.PARAMETER Pattern
    Pattern to search for in logs

.PARAMETER Tail
    Number of lines to show from end of log (default: 50)

.PARAMETER PublishProfile
    Publish profile to use for deployment. Default: Local.1Node.xml
    For remote clusters, use cluster-specific profiles (e.g., anz-ds5-dev-us-wus2-1.xml)

.EXAMPLE
    .\sf-local.ps1 deploy SonarCoreApplication
    Build and deploy SonarCoreApplication to local cluster

.EXAMPLE
    .\sf-local.ps1 deploy SonarCoreApplication -PublishProfile anz-ds5-dev-us-wus2-1.xml
    Build and deploy SonarCoreApplication to remote cluster with AAD authentication

.EXAMPLE
    .\sf-local.ps1 health SonarCoreApplication
    Get health status of SonarCoreApplication

.EXAMPLE
    .\sf-local.ps1 logs QueueService
    View recent logs for QueueService

.EXAMPLE
    .\sf-local.ps1 db-query SonarQueue "SELECT TOP 5 * FROM dbo.Message"
    Execute SQL query against SonarQueue database
#>

param(
    [Parameter(Position=0, Mandatory=$true)]
    [string]$Command,
    
    [Parameter(Position=1)]
    [string]$Arg1,
    
    [Parameter(Position=2)]
    [string]$Arg2,
    
    [Parameter(Position=3)]
    [string]$Arg3,
    
    [int]$Tail = 50,
    
    [string]$RootPath = $PWD.Path,
    
    [string]$PublishProfile = "Local.1Node.xml"
)

$ErrorActionPreference = "Stop"

$LogsPath = "C:\SonarLogs"

# Helper: Connect to Service Fabric cluster
function Connect-SF {
    Import-Module ServiceFabric -WarningAction SilentlyContinue
    Connect-ServiceFabricCluster | Out-Null
}

# Helper: Find service project path by searching recursively from root
function Find-ServicePath {
    param([string]$ServiceName)
    $found = Get-ChildItem -Path $RootPath -Directory -Recurse -Filter $ServiceName -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '\\(bin|obj|pkg|build|packages|output|outputs|node_modules|\.vs|\.pipelines|\.git)\\' } |
        Select-Object -First 1
    if ($found) { return $found.FullName }
    return $null
}

switch ($Command.ToLower()) {
    
    #region Deployment Commands
    
    "deploy" {
        $AppName = $Arg1
        if (-not $AppName) { Write-Error "Usage: sf-local.ps1 deploy <ApplicationName> [-PublishProfile <Profile>]"; exit 1 }
        
        Write-Host "Building $AppName..." -ForegroundColor Cyan
        $sfproj = "$RootPath\Deployment\$AppName\$AppName.sfproj"
        & msbuild $sfproj /t:Package /p:Configuration=Release /p:Platform=x64 /v:m
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Deploying $AppName with profile $PublishProfile..." -ForegroundColor Cyan
            & "$RootPath\Deployment\Scripts\Deploy-ServiceFabricApplication.ps1" -ApplicationName $AppName -PublishProfileFile $PublishProfile
        } else {
            Write-Error "Build failed"
        }
    }
    
    "build" {
        $AppName = $Arg1
        if (-not $AppName) { Write-Error "Usage: sf-local.ps1 build <ApplicationName>"; exit 1 }
        
        Write-Host "Building $AppName..." -ForegroundColor Cyan
        $sfproj = "$RootPath\Deployment\$AppName\$AppName.sfproj"
        & msbuild $sfproj /t:Package /p:Configuration=Release /p:Platform=x64 /v:m
    }
    
    "remove" {
        $AppName = $Arg1
        if (-not $AppName) { Write-Error "Usage: sf-local.ps1 remove <ApplicationName>"; exit 1 }
        
        Connect-SF
        Write-Host "Removing fabric:/$AppName..." -ForegroundColor Yellow
        Remove-ServiceFabricApplication -ApplicationName "fabric:/$AppName" -Force
        
        # Get app type info and unregister
        $app = Get-ServiceFabricApplicationType | Where-Object { $_.ApplicationTypeName -match $AppName }
        if ($app) {
            Unregister-ServiceFabricApplicationType -ApplicationTypeName $app.ApplicationTypeName -ApplicationTypeVersion $app.ApplicationTypeVersion -Force
        }
        Write-Host "Removed." -ForegroundColor Green
    }
    
    #endregion
    
    #region Cluster Info Commands
    
    "apps" {
        Connect-SF
        Get-ServiceFabricApplication | Format-Table ApplicationName, ApplicationTypeName, ApplicationTypeVersion
    }
    
    "services" {
        $AppName = $Arg1
        if (-not $AppName) { Write-Error "Usage: sf-local.ps1 services <ApplicationName>"; exit 1 }
        
        Connect-SF
        Get-ServiceFabricService -ApplicationName "fabric:/$AppName" | Format-Table ServiceName, ServiceTypeName, ServiceStatus
    }
    
    "health" {
        $AppName = $Arg1
        $ServiceName = $Arg2
        
        if (-not $AppName) { Write-Error "Usage: sf-local.ps1 health <ApplicationName> [ServiceName]"; exit 1 }
        
        Connect-SF
        
        if ($ServiceName) {
            # Service health
            Get-ServiceFabricServiceHealth -ServiceName "fabric:/$AppName/$ServiceName"
        } else {
            # Application health summary
            $health = Get-ServiceFabricApplicationHealth -ApplicationName "fabric:/$AppName"
            
            Write-Host "`nApplication: fabric:/$AppName" -ForegroundColor Cyan
            Write-Host "Health State: $($health.AggregatedHealthState)" -ForegroundColor $(if ($health.AggregatedHealthState -eq 'Ok') { 'Green' } else { 'Red' })
            
            Write-Host "`nService Health States:" -ForegroundColor Cyan
            $health.ServiceHealthStates | Format-Table ServiceName, AggregatedHealthState
            
            if ($health.HealthEvents.Count -gt 0) {
                Write-Host "Health Events:" -ForegroundColor Yellow
                $health.HealthEvents | Where-Object { $_.HealthState -ne 'Ok' } | Format-List Property, HealthState, Description
            }
        }
    }
    
    "nodes" {
        Connect-SF
        Get-ServiceFabricNode | Format-Table NodeName, NodeStatus, IpAddressOrFQDN, NodeUpTime
    }
    
    "cluster-health" {
        Connect-SF
        Get-ServiceFabricClusterHealth
    }
    
    #endregion
    
    #region Log Commands
    
    "logs" {
        $ServiceName = $Arg1
        if (-not $ServiceName) { Write-Error "Usage: sf-local.ps1 logs <ServiceName> [Tail]"; exit 1 }
        if ($Arg2) { $Tail = [int]$Arg2 }
        
        $logFile = Get-ChildItem $LogsPath -Recurse -Filter "$ServiceName*.log" | 
            Sort-Object LastWriteTime -Descending | 
            Select-Object -First 1
        
        if ($logFile) {
            Write-Host $logFile.FullName -ForegroundColor Cyan
            Get-Content $logFile.FullName -Tail $Tail
        } else {
            Write-Warning "No log files found for $ServiceName"
        }
    }
    
    "logs-watch" {
        $ServiceName = $Arg1
        if (-not $ServiceName) { Write-Error "Usage: sf-local.ps1 logs-watch <ServiceName>"; exit 1 }
        
        Write-Host "Watching logs for $ServiceName (Ctrl+C to stop)..." -ForegroundColor Cyan
        while ($true) {
            Clear-Host
            $logFile = Get-ChildItem $LogsPath -Filter "$ServiceName*.log" | 
                Sort-Object LastWriteTime -Descending | 
                Select-Object -First 1
            
            if ($logFile) {
                Write-Host $logFile.Name -ForegroundColor Yellow
                Get-Content $logFile.FullName -Tail 30
            }
            Start-Sleep 2
        }
    }
    
    "logs-errors" {
        $ServiceName = $Arg1
        $Count = if ($Arg2) { [int]$Arg2 } else { 5 }
        
        $filter = if ($ServiceName) { "$ServiceName*.log" } else { "*.log" }
        
        Get-ChildItem $LogsPath -Filter $filter | 
            Sort-Object LastWriteTime -Descending | 
            Select-Object -First $Count | 
            ForEach-Object { 
                Write-Host $_.Name -ForegroundColor Yellow
                Get-Content $_.FullName | Select-String 'Error|Exception' | Select-Object -First 5
                Write-Host ""
            }
    }
    
    "logs-search" {
        $ServiceName = $Arg1
        $Pattern = $Arg2
        if (-not $ServiceName -or -not $Pattern) { Write-Error "Usage: sf-local.ps1 logs-search <ServiceName> <Pattern>"; exit 1 }
        
        $logFile = Get-ChildItem $LogsPath -Filter "$ServiceName*.log" | 
            Sort-Object LastWriteTime -Descending | 
            Select-Object -First 1
        
        if ($logFile) {
            Write-Host "Searching $($logFile.Name) for '$Pattern'..." -ForegroundColor Cyan
            Get-Content $logFile.FullName | Select-String $Pattern
        }
    }
    
    #endregion
    
    #region Event Log Commands
    
    "events" {
        $Count = if ($Arg1) { [int]$Arg1 } else { 20 }
        
        Get-EventLog -Newest $Count -LogName 'Application' -EntryType Error | 
            Where-Object { $_.Source -match '.NET' -or $_.Source -match 'Application Error' } |
            Format-List TimeGenerated, Source, Message
    }
    
    "sf-events" {
        $AppName = $Arg1
        $Count = if ($Arg2) { [int]$Arg2 } else { 50 }
        
        $events = Get-WinEvent -LogName 'Microsoft-ServiceFabric/Operational' -MaxEvents $Count
        
        if ($AppName) {
            $events = $events | Where-Object { $_.Message -match $AppName }
        }
        
        $events | Format-List TimeCreated, Message
    }
    
    #endregion
    
    #region Database Commands
    
    "db-list" {
        sqlcmd -S LOCALHOST -E -Q "SELECT name FROM sys.databases WHERE name LIKE 'Sonar%' ORDER BY name"
    }
    
    "db-tables" {
        $Database = $Arg1
        if (-not $Database) { Write-Error "Usage: sf-local.ps1 db-tables <DatabaseName>"; exit 1 }
        
        sqlcmd -S LOCALHOST -d $Database -E -Q "SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE' ORDER BY TABLE_NAME"
    }
    
    "db-schema" {
        $Database = $Arg1
        $Table = $Arg2
        if (-not $Database -or -not $Table) { Write-Error "Usage: sf-local.ps1 db-schema <DatabaseName> <TableName>"; exit 1 }
        
        sqlcmd -S LOCALHOST -d $Database -E -Q "SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = '$Table' ORDER BY ORDINAL_POSITION"
    }
    
    "db-query" {
        $Database = $Arg1
        $Query = $Arg2
        if (-not $Database -or -not $Query) { Write-Error "Usage: sf-local.ps1 db-query <DatabaseName> '<SQL Query>'"; exit 1 }
        
        sqlcmd -S LOCALHOST -d $Database -E -Q $Query
    }
    
    "db-procs" {
        $Database = $Arg1
        if (-not $Database) { Write-Error "Usage: sf-local.ps1 db-procs <DatabaseName>"; exit 1 }
        
        sqlcmd -S LOCALHOST -d $Database -E -Q "SELECT name FROM sys.procedures ORDER BY name"
    }
    
    "db-proc-code" {
        $Database = $Arg1
        $ProcName = $Arg2
        if (-not $Database -or -not $ProcName) { Write-Error "Usage: sf-local.ps1 db-proc-code <DatabaseName> <ProcedureName>"; exit 1 }
        
        sqlcmd -S LOCALHOST -d $Database -E -Q "EXEC sp_helptext '$ProcName'"
    }
    
    #endregion
    
    #region Configuration Commands
    
    "config" {
        $ServiceName = $Arg1
        if (-not $ServiceName) { Write-Error "Usage: sf-local.ps1 config <ServiceName>"; exit 1 }
        
        $servicePath = Find-ServicePath $ServiceName
        if (-not $servicePath) {
            Write-Error "Service '$ServiceName' not found"
            exit 1
        }
        
        # Check for appsettings.local.json
        $appSettings = "$servicePath\appsettings.local.json"
        if (Test-Path $appSettings) {
            Write-Host "=== appsettings.local.json ===" -ForegroundColor Cyan
            Get-Content $appSettings | ConvertFrom-Json | ConvertTo-Json -Depth 5
        }
        
        # Check for Settings.xml
        $settingsXml = "$servicePath\PackageRoot\Config\Settings.xml"
        if (Test-Path $settingsXml) {
            Write-Host "`n=== Settings.xml ===" -ForegroundColor Cyan
            Get-Content $settingsXml
        }
    }
    
    #endregion
    
    "help" {
        Get-Help $MyInvocation.MyCommand.Path -Detailed
    }
    
    default {
        Write-Host "Service Fabric Cluster Management Script" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Deployment:" -ForegroundColor Yellow
        Write-Host "  deploy <AppName> [-PublishProfile <Profile>]"
        Write-Host "                             Build and deploy application"
        Write-Host "                             Default profile: Local.1Node.xml"
        Write-Host "  build <AppName>            Build application package only"
        Write-Host "  remove <AppName>           Remove application from cluster"
        Write-Host ""
        Write-Host "Cluster Info:" -ForegroundColor Yellow
        Write-Host "  apps                       List all applications"
        Write-Host "  services <AppName>         List services in application"
        Write-Host "  health <AppName> [Svc]     Get health status"
        Write-Host "  nodes                      List cluster nodes"
        Write-Host "  cluster-health             Get cluster health"
        Write-Host ""
        Write-Host "Logs:" -ForegroundColor Yellow
        Write-Host "  logs <ServiceName> [N]     View last N lines of logs"
        Write-Host "  logs-watch <ServiceName>   Watch logs in real-time"
        Write-Host "  logs-errors [ServiceName]  Search for errors in logs"
        Write-Host "  logs-search <Svc> <Pattern> Search logs for pattern"
        Write-Host ""
        Write-Host "Events:" -ForegroundColor Yellow
        Write-Host "  events [N]                 View .NET errors from Event Log"
        Write-Host "  sf-events [AppName] [N]    View Service Fabric events"
        Write-Host ""
        Write-Host "Database:" -ForegroundColor Yellow
        Write-Host "  db-list                    List Sonar databases"
        Write-Host "  db-tables <DB>             List tables in database"
        Write-Host "  db-schema <DB> <Table>     Get table schema"
        Write-Host "  db-query <DB> '<SQL>'      Execute SQL query"
        Write-Host "  db-procs <DB>              List stored procedures"
        Write-Host "  db-proc-code <DB> <Proc>   View procedure code"
        Write-Host ""
        Write-Host "Config:" -ForegroundColor Yellow
        Write-Host "  config <ServiceName>       View service configuration"
        Write-Host ""
        Write-Host "Examples:" -ForegroundColor Green
        Write-Host "  .\sf-local.ps1 deploy SonarCoreApplication"
        Write-Host "  .\sf-local.ps1 deploy SonarCoreApplication -PublishProfile anz-ds5-dev-us-wus2-1.xml"
        Write-Host "  .\sf-local.ps1 health SonarCoreApplication"
        Write-Host "  .\sf-local.ps1 logs QueueService"
        Write-Host "  .\sf-local.ps1 db-query SonarQueue 'SELECT TOP 5 * FROM dbo.Message'"
    }
}
