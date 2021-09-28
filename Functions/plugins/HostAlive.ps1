param([Hashtable]$GlobalConfig, [System.Xml.XmlElement]$ModuleConfig)


function GetHostAliveAsync {
    param ([System.Xml.XmlElement]$ModuleConfig)
    $hosts = $ModuleConfig.Host.Name.ToLower();
    $pingResults=GetPingResultAsync -hosts $hosts
    GetMetricHostIsAlive -pingResults $pingResults
    }


. $PSScriptRoot\GetPingResultAsync.ps1

. $PSScriptRoot\GetMetricHostIsAlive.ps1

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

return [pscustomobject]@{PluginName = "HostAlive"; FunctionName="GetHostAliveAsync"; GlobalConfig=$GlobalConfig; ModuleConfig=$ModuleConfig; NodeHostName=$NodeHostName; MetricPath=$MetricPath }
