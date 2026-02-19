---
name: service-fabric
description: Deploy, monitor, and debug Service Fabric apps—build/deploy to local or remote clusters, check health and logs, query SQL databases, and view configurations.
---

# Service Fabric Deployment & Troubleshooting Skill

This skill supports deploying Service Fabric applications to both local development clusters and remote Azure clusters with AAD authentication.

| Scenario | What You Need | Jump To |
|----------|---------------|---------|
| **Deploy to Local** | Deploy an SF app to local cluster | [Deployment Workflow](#deployment-workflow) |
| **Deploy to Remote** | Deploy to Azure cluster with AAD auth | [Remote Deployment](#remote-cluster-deployment) |
| **Troubleshoot Only** | Debug a running app (already deployed) | [Troubleshooting Tools](#service-fabric-powershell-commands) |
| **Deploy + Troubleshoot** | Iterate on code with build-deploy-test cycle | [Quick Commands](#quick-commands) |

**Trigger:** User wants to:
- Deploy a Service Fabric application to local or remote cluster
- Troubleshoot/debug a locally running Service Fabric application
- Iterate on code changes with repeated build-deploy-verify cycles

**IMPORTANT**: Use the `sf.ps1` script from the user profile skills directory based on which agent you are by replacing the token `[REPLACE_ME]` with the appropriate path:
- If you are _Roo_ based agent, use: `$scriptPath = "~\.roo\skills\service-fabric\scripts\sf.ps1"`
- If you are _GitHub Copilot_ based agent, use: `$scriptPath = "~\.copilot\skills\service-fabric\scripts\sf.ps1"`

## Prerequisites

1. **Local cluster:** Service Fabric Local Cluster Manager running (system tray)
2. **Remote cluster:** AAD authentication configured in publish profile
3. **For deployment:** Application package built with `/t:Package` target
4. **For troubleshooting:** Application already deployed and running

## Deployment Workflow

### Step 1: Identify the Application

Ask the user which application to deploy if not specified. Available applications:

| Application | Description |
|-------------|-------------|
| `SonarCoreApplication` | Core services (BlobService, QueueService) |
| `PlatformApplication` | Platform services |
| `PlatformMonitorApplication` | Platform monitoring |
| `SonarArchiveApplication` | Archive services |
| `SonarDetonationApplication` | Detonation services |
| `SonarExportApplication` | Export services |
| `SonarFeedApplication` | Feed services |
| `SonarRepairApplication` | Repair services |
| `SslCertificateMonitorApplication` | SSL certificate monitoring |
| `ToolsetApplication` | Toolset services |
| `AzureVmDetonationApplication` | Azure VM detonation services |

### Step 2: Build and Deploy (Local Cluster)


```powershell
pwsh -Command "$scriptPath = [REPLACE_ME]; & $scriptPath deploy <ApplicationName>"
```

To build the package only (without deploying):

```powershell
pwsh -Command "$scriptPath = [REPLACE_ME]; & $scriptPath build <ApplicationName>"
```

### Step 3: Verify Deployment

The script automatically verifies services are ready. You can also check:

- **Service Fabric Explorer:** http://localhost:19080/Explorer
- **PowerShell:** `Get-ServiceFabricApplication -ApplicationName "fabric:/<ApplicationName>"`

## Remote Cluster Deployment

To deploy to a remote Azure cluster, use the `-PublishProfile` parameter with a cluster-specific profile:

```powershell
pwsh -Command "$scriptPath = [REPLACE_ME]; & $scriptPath deploy <ApplicationName> -PublishProfile <ClusterProfile>.xml"
```

The script will:
1. Build the application package
2. Connect to the remote cluster using AAD authentication
3. Deploy the application using the cluster's publish profile

**Available publish profiles** are located in each application's `PublishProfiles` folder (e.g., `Deployment\SonarCoreApplication\PublishProfiles\`).

## Example Commands

**Deploy to local cluster (default):**
```powershell
pwsh -Command "$scriptPath = [REPLACE_ME]; & $scriptPath deploy SonarCoreApplication"
```

**Deploy to remote cluster:**
```powershell
pwsh -Command "$scriptPath = [REPLACE_ME]; & $scriptPath deploy SonarCoreApplication -PublishProfile anz-ds5-dev-us-wus2-1.xml"
```

**Build only (no deploy):**
```powershell
pwsh -Command "$scriptPath = [REPLACE_ME]; & $scriptPath build PlatformApplication"
```

**Remove application from cluster:**
```powershell
pwsh -Command "$scriptPath = [REPLACE_ME]; & $scriptPath remove ToolsetApplication"
```

---

## Service Fabric PowerShell Commands

All cluster commands are available through the `sf.ps1` script, which handles cluster connection automatically. **Run all commands from the repo root directory.**

### Application Management

**List all applications:**
```powershell
pwsh -Command "$scriptPath = [REPLACE_ME]; & $scriptPath apps"
```

**Remove application:**
```powershell
pwsh -Command "$scriptPath = [REPLACE_ME]; & $scriptPath remove <ApplicationName>"
```

### Service Management

**List services in an application:**
```powershell
pwsh -Command "$scriptPath = [REPLACE_ME]; & $scriptPath services <ApplicationName>"
```

### Health Queries

**Get application health summary:**
```powershell
pwsh -Command "$scriptPath = [REPLACE_ME]; & $scriptPath health <ApplicationName>"
```

**Get service health:**
```powershell
pwsh -Command "$scriptPath = [REPLACE_ME]; & $scriptPath health <ApplicationName> <ServiceName>"
```

### Node and Cluster Info

**List cluster nodes:**
```powershell
pwsh -Command "$scriptPath = [REPLACE_ME]; & $scriptPath nodes"
```

**Get cluster health:**
```powershell
pwsh -Command "$scriptPath = [REPLACE_ME]; & $scriptPath cluster-health"
```

---

## Database Debugging

### Local Database Reference

Services use local SQL Server databases. Connection strings are in `appsettings.local.json` or `ENV-local` section in `Settings.xml`:

| Service | Database | Config Key |
|---------|----------|------------|
| QueueService2 | SonarQueue | `QueueDatabase` |
| BlobService2 | SonarBlob | `BlobDatabase` |
| ConfigurationService | SonarConfiguration | via config |
| FrontendService | SonarFrontend | via config |

### SQL Server Exploration

**List all Sonar databases:**
```powershell
pwsh -Command "$scriptPath = [REPLACE_ME]; & $scriptPath db-list"
```

**List tables in a database:**
```powershell
pwsh -Command "$scriptPath = [REPLACE_ME]; & $scriptPath db-tables <DatabaseName>"
```

**Get table schema (columns and types):**
```powershell
pwsh -Command "$scriptPath = [REPLACE_ME]; & $scriptPath db-schema <DatabaseName> <TableName>"
```

**List stored procedures:**
```powershell
pwsh -Command "$scriptPath = [REPLACE_ME]; & $scriptPath db-procs <DatabaseName>"
```

**View stored procedure code:**
```powershell
pwsh -Command "$scriptPath = [REPLACE_ME]; & $scriptPath db-proc-code <DatabaseName> <ProcedureName>"
```

### Data Queries

**Execute SQL query:**
```powershell
pwsh -Command "$scriptPath = [REPLACE_ME]; & $scriptPath db-query <DatabaseName> '<SQL Query>'"
```

### Common Database Queries

**SonarQueue - View queue messages:**
```powershell
pwsh -Command "$scriptPath = [REPLACE_ME]; & $scriptPath db-query SonarQueue 'SELECT MessageId, QueueName, State, Label, LEN(Data) as DataLen FROM dbo.Message ORDER BY MessageId DESC'"
```

**SonarQueue - View messages in specific queue:**
```powershell
pwsh -Command "$scriptPath = [REPLACE_ME]; & $scriptPath db-query SonarQueue 'SELECT MessageId, State, DequeueCount, Label FROM dbo.Message WHERE QueueName = ''<QueueName>'' ORDER BY MessageId'"
```

**SonarBlob - View blob metadata:**
```powershell
pwsh -Command "$scriptPath = [REPLACE_ME]; & $scriptPath db-query SonarBlob 'SELECT TOP 10 BlobName, Length, LastUpdateDate FROM dbo.Blob ORDER BY LastUpdateDate DESC'"
```

---

## Log Analysis

### Service Fabric Log Locations

| Log Type | Location |
|----------|----------|
| **Sonar application logs** | `C:\SonarLogs\` |
| **SF application work folder** | `C:\SfDevCluster\Data\_App\_Node_0\<AppTypeName>_App<N>\` |
| **Service Fabric system logs** | `C:\SfDevCluster\Log\Traces\` |
| **ETW traces** | `C:\SfDevCluster\Log\Traces\*.etl` |

### Log Commands

**View recent logs for a service:**
```powershell
pwsh -Command "$scriptPath = [REPLACE_ME]; & $scriptPath logs <ServiceName>"
```

**View with custom tail count:**
```powershell
pwsh -Command "$scriptPath = [REPLACE_ME]; & $scriptPath logs <ServiceName> 100"
```

**Search logs for pattern:**
```powershell
pwsh -Command "$scriptPath = [REPLACE_ME]; & $scriptPath logs-search <ServiceName> '<Pattern>'"
```

**Search for errors in logs:**
```powershell
pwsh -Command "$scriptPath = [REPLACE_ME]; & $scriptPath logs-errors <ServiceName>"
```

**Watch logs in real-time:**
```powershell
pwsh -Command "$scriptPath = [REPLACE_ME]; & $scriptPath logs-watch <ServiceName>"
```

### Windows Event Logs

**View .NET Runtime errors:**
```powershell
pwsh -Command "$scriptPath = [REPLACE_ME]; & $scriptPath events"
```

**View Service Fabric events:**
```powershell
pwsh -Command "$scriptPath = [REPLACE_ME]; & $scriptPath sf-events"
```

**Filter events by application:**
```powershell
pwsh -Command "$scriptPath = [REPLACE_ME]; & $scriptPath sf-events <ApplicationName>"
```

---

## Quick Commands

### Build and Deploy (One-Liner)

```powershell
pwsh -Command "$scriptPath = [REPLACE_ME]; & $scriptPath deploy <AppName>"
```

### Check Configuration

**View service configuration (appsettings.local.json and Settings.xml):**
```powershell
pwsh -Command "$scriptPath = [REPLACE_ME]; & $scriptPath config <ServiceName>"
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| **Cluster not running** | Start via Service Fabric Local Cluster Manager (system tray) |
| **Package not found** | Build with `msbuild /t:Package /p:Configuration=Release /p:Platform=x64` |
| **Services not starting** | Check `C:\SonarLogs` and Event Log for errors |
| **Connection refused** | Ensure local cluster is running on port 19080 |
| **Service crashes** | Check `Get-EventLog -LogName Application -EntryType Error` |
| **Missing dependencies** | Verify all NuGet packages restored, rebuild package |
| **Database errors** | Use `sqlcmd` to verify database exists and is accessible |

## References

- [`sf.ps1`](scripts/sf.ps1) - Unified management script. Run without arguments for help.
- [`Deploy-ServiceFabricApplication.ps1`](../../Deployment/Scripts/Deploy-ServiceFabricApplication.ps1) - Underlying deployment script (supports local and remote clusters)
- [Service Fabric Explorer (Local)](http://localhost:19080/Explorer) - Local cluster management UI
- `C:\SonarLogs\` - Sonar application logs
- `C:\SfDevCluster\` - Local SF cluster data and logs
