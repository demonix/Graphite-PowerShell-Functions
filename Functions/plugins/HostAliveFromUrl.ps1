param([Hashtable]$GlobalConfig, [System.Xml.XmlElement]$ModuleConfig)


function GetHostAliveAsyncFromUrl {
    param ([pscustomobject]$PluginConfig )

    try {
    $Hostlist=irm -Uri $PluginConfig.ModuleConfig.Url -Headers (@{"X-Kontur-Apikey" = $PluginConfig.ModuleConfig.apikey})
    $hosts = $HostList | ForEach-Object { $_.Split('.')[0].ToLower() }
    
    $PluginConfig.Hosts=$hosts

       } catch {
                Write-Warning "Url: $_."
                $hosts=$PluginConfig.Hosts
            }

    $pingResults=GetPingResultAsync -hosts $hosts
    GetMetricHostIsAlive -pingResults $pingResults
    }
   
. $PSScriptRoot\GetPingResultAsync.ps1
    
. $PSScriptRoot\GetMetricHostIsAlive.ps1


$PluginConfig = [pscustomobject]@{ModuleConfig = $ModuleConfig; Hosts=@()}



$MetricPath = $GlobalConfig.MetricPath
$NodeHostName = $GlobalConfig.NodeHostName

if ($ModuleConfig.HasAttribute("CustomPrefix"))
{
	$MetricPath = $ModuleConfig.GetAttribute("CustomPrefix")
}
if ($ModuleConfig.HasAttribute("CustomNodeHostName"))
{
	$NodeHostName = $ModuleConfig.GetAttribute("CustomNodeHostName")
}

return [pscustomobject]@{PluginName = "HostAliveFromUrl"; FunctionName="GetHostAliveAsyncFromUrl"; GlobalConfig=$GlobalConfig; ModuleConfig=$PluginConfig; NodeHostName=$NodeHostName; MetricPath=$MetricPath }
