param([Hashtable]$GlobalConfig, [System.Xml.XmlElement]$ModuleConfig)


function GetHostAliveAsyncFromUrl {
    param ([System.Xml.XmlElement]$ModuleConfig)
    
    $HostList=irm -Uri $ModuleConfig.Url -Headers (@{"X-Kontur-Apikey" = $ModuleConfig.apikey}) 
    $hosts = $HostList | ForEach-Object { $_.Split('.')[0].ToLower() }
    $pingResults=GetPingResultAsync -hosts $hosts
    GetMetricHostIsAliveFromUrl -pingResults $pingResults
    }
    
function GetMetricHostIsAliveFromUrl {
    param ( $pingResults )  
    $pingResults | ForEach-Object {         
    $HostMetric=$_.Host
    $ValueMetric=$_.Value
    [pscustomobject]@{Path="\\$HostMetric\IsAlive";Value="$ValueMetric"}

    [pscustomobject]@{Path="\\$HostMetric\$(($env:COMPUTERNAME).ToLower())\IsAlive";Value="$ValueMetric"}
    }

   }

. $PSScriptRoot\GetPingResultAsync.ps1

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

return [pscustomobject]@{PluginName = "HostAliveFromUrl"; FunctionName="GetHostAliveAsyncFromUrl"; GlobalConfig=$GlobalConfig; ModuleConfig=$ModuleConfig; NodeHostName=$NodeHostName; MetricPath=$MetricPath }
