param([Hashtable]$GlobalConfig, [System.Xml.XmlElement]$ModuleConfig)


function GetExampleCounters {
param ([System.Xml.XmlElement]$ModuleConfig)
			
[pscustomobject]@{ Path="$($this.NodeHostName).Example"; Value=1}
			
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

return [pscustomobject]@{PluginName = "ExampleCounters"; FunctionName="GetExampleCounters"; GlobalConfig=$GlobalConfig; ModuleConfig=$ModuleConfig; NodeHostName=$NodeHostName; MetricPath=$MetricPath }




