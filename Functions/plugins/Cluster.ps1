param([Hashtable]$GlobalConfig, [System.Xml.XmlElement]$ModuleConfig)


function GetClusterStatus {
param ([System.Xml.XmlElement]$ModuleConfig)

$clusterName = (Get-Cluster).name
			Get-ClusterGroup | select GroupType, OwnerNode, Name, State | ? GroupType -ne 'AvailableStorage' | ? GroupType -ne 'VirtualMachine' | %{ [pscustomobject]@{ Path="\\$($clusterName)\$($env:COMPUTERNAME)\ClusterGroupState\$($_.GroupType)\$($_.Name.Replace('(','').Replace(')',''))"; Value=[int]$_.State } }
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

return [pscustomobject]@{PluginName = "ClusterStatus"; FunctionName="GetClusterStatus"; GlobalConfig=$GlobalConfig; ModuleConfig=$ModuleConfig; NodeHostName=$NodeHostName; MetricPath=$MetricPath }
