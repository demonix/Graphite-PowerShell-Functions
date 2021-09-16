param([Hashtable]$GlobalConfig, [System.Xml.XmlElement]$ModuleConfig)


function GetHostAliveAsync {
    param ([System.Xml.XmlElement]$ModuleConfig)
    
    $Vmmenv = $ModuleConfig.Vmmenv

    $Url = "https://stat.kontur.ru/vmminfo/api/v1/vmhost?env=$Vmmenv"
    $HostConfig=irm -Uri $Url -Headers (@{"X-Kontur-Apikey" = 'api'}) 
    
    $hosts = $HostConfig | ForEach-Object { $_.Split('.')[0].ToLower() }

    $pingResults=GetPingResultAsync -hosts $hosts
    GetMetricHostIsAlive -pingResults $pingResults
    }
    
function GetMetricHostIsAlive {
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

return [pscustomobject]@{PluginName = "HostAliveFromUrl"; FunctionName="GetHostAliveAsync"; GlobalConfig=$GlobalConfig; ModuleConfig=$ModuleConfig; NodeHostName=$NodeHostName; MetricPath=$MetricPath }
