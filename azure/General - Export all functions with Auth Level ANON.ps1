#Requires -Version 5.1
<#
Lists all functions of a given subscription with httpTriggers, which have the auth Level 'anonymous' or 'function'.
Prerequisite: Azure CLI & at least read rights on the given subscription
#>

param(
  [string]$SubscriptionId = "SUBSCRIPTION-ID",
  [string]$CsvPath = $null
)

function Invoke-AzJson {
  param([string]$Cli)
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = "cmd.exe"
  $psi.Arguments = "/c $Cli 2>&1"
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError  = $true
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true
  $p = [System.Diagnostics.Process]::Start($psi)
  $out = $p.StandardOutput.ReadToEnd()
  $p.WaitForExit()
  if ($p.ExitCode -ne 0) { return $null }
  if ([string]::IsNullOrWhiteSpace($out)) { return $null }
  try { return ($out | ConvertFrom-Json) } catch { return $null }
}

function Ensure-Sub {
  param([string]$SubId)
  if ([string]::IsNullOrWhiteSpace($SubId)) {
    $subs = Invoke-AzJson -Cli 'az account list --query "[].{name:name,id:id,isDefault:isDefault}" --only-show-errors -o json'
    if (-not $subs) { throw "No subscription found. Execute 'az login'." }
    $default = $null
    foreach ($s in $subs) { if ($s.isDefault -eq $true) { $default = $s; break } }
    $SubId = if ($default) { $default.id } else { $subs[0].id }
  }
  [void](Invoke-AzJson -Cli ("az account set --subscription {0} --only-show-errors" -f $SubId))
  return $SubId
}

function Get-FunctionsFromAzCli {
  param([string]$Sub,[string]$Rg,[string]$App)
  $cmd = 'az functionapp function list --subscription "{0}" --resource-group "{1}" --name "{2}" --only-show-errors -o json' -f $Sub,$Rg,$App
  return (Invoke-AzJson -Cli $cmd)
}

function Get-FunctionsFromArmList {
  param([string]$Sub,[string]$Rg,[string]$App)
  $uri = ('https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Web/sites/{2}/functions/list?api-version=2023-12-01' -f $Sub,$Rg,$App)
  $cmd = 'az rest --method post --url "{0}" --only-show-errors -o json' -f $uri
  return (Invoke-AzJson -Cli $cmd)
}

function Get-AppFunctions {
  param([string]$Sub,[string]$Rg,[string]$App)
  $f = Get-FunctionsFromAzCli -Sub $Sub -Rg $Rg -App $App
  if ($f) { return $f }
  return (Get-FunctionsFromArmList -Sub $Sub -Rg $Rg -App $App)
}

$SubscriptionId = Ensure-Sub -SubId $SubscriptionId

# Function Apps
$apps = Invoke-AzJson -Cli ('az functionapp list --subscription "{0}" --query "[].{{name:name,rg:resourceGroup}}" --only-show-errors -o json' -f $SubscriptionId)
if (-not $apps -or $apps.Count -eq 0) { Write-Output ("No function apps found in subscription {0}." -f $SubscriptionId); return }

$result = New-Object System.Collections.Generic.List[object]

foreach ($app in $apps) {
  $funcs = Get-AppFunctions -Sub $SubscriptionId -Rg ([string]$app.rg) -App ([string]$app.name)
  if (-not $funcs) { continue }

  foreach ($f in $funcs) {
    $bindings = @()
    if ($f.PSObject.Properties.Name -contains 'config' -and $null -ne $f.config) {
      if ($f.config.PSObject.Properties.Name -contains 'bindings' -and $null -ne $f.config.bindings) { $bindings = $f.config.bindings }
    }
    if ($bindings.Count -eq 0) { continue }

    foreach ($b in $bindings) {
      $bType = $null; $bAuth = $null; $bMethods = $null
      if ($b.PSObject.Properties.Name -contains 'type')      { $bType = [string]$b.type }
      if ($b.PSObject.Properties.Name -contains 'authLevel') { $bAuth = [string]$b.authLevel }
      if ($b.PSObject.Properties.Name -contains 'methods')   { $bMethods = $b.methods }

      if ($bType -eq 'httpTrigger' -and $bAuth) {
        $authLower = $bAuth.ToLower()
        if ($authLower -eq 'anonymous' -or $authLower -eq 'function') {
          $methodsCollected = @()
          if ($bMethods -ne $null) {
            if ($bMethods -is [System.Array]) { $methodsCollected = $bMethods }
            else { $methodsCollected = @($bMethods) }
          }
          $methods = ($methodsCollected -join ',')
          $invoke = $null
          if ($f.PSObject.Properties.Name -contains 'invoke_url_template') { $invoke = [string]$f.invoke_url_template }

          $result.Add([pscustomobject]@{
            SubscriptionId = $SubscriptionId
            ResourceGroup  = [string]$app.rg
            FunctionApp    = [string]$app.name
            FunctionName   = [string]$f.name
            Methods        = $methods
            AuthLevel      = $authLower        # 'anonymous' oder 'function'
            InvokeUrl      = $invoke
          }) | Out-Null
        }
      }
    }
  }
}

if ($result.Count -eq 0) { Write-Output "No HTTP-Fnctions found with authLevel 'anonymous' or 'function'."; return }

$result |
  Sort-Object ResourceGroup, FunctionApp, FunctionName |
  Format-Table -AutoSize SubscriptionId, ResourceGroup, FunctionApp, FunctionName, Methods, AuthLevel, InvokeUrl

if ($CsvPath) {
  $result | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $CsvPath
  Write-Output ("CSV exported: {0}" -f $CsvPath)
}
