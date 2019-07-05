param([Hashtable]$GlobalConfig, [System.Xml.XmlElement]$ModuleConfig)


function GetVMMHostAliveness {
param ([System.Xml.XmlElement]$ModuleConfig)
	
$vmmHosts = Get-SCVMHost -VMMServer $ModuleConfig.VmmServer
$Ping = [System.Net.NetworkInformation.Ping]::new()
$vmmHosts | %{
   $pingReply = $Ping.Send($_.fqdn,150)
   $isAlive = $pingReply.Status -eq Success
   [pscustomobject]@{ Path="\\$($_.ComputerName)\IsAlive"; Value=[int]$isAlive }
}
			
}

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

return [pscustomobject]@{PluginName = "VMMHostAliveness"; FunctionName="GetVMMHostAliveness"; GlobalConfig=$GlobalConfig; ModuleConfig=$ModuleConfig; NodeHostName=$NodeHostName; MetricPath=$MetricPath }





