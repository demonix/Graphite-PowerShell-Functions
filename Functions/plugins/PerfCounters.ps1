param([Hashtable]$GlobalConfig, [System.Xml.XmlElement]$ModuleConfig)


function GetPerfCounters {
param ([System.Xml.XmlElement]$ModuleConfig)
			
$couterSamples = (Get-Counter -Counter $ModuleConfig.Counter.Name -SampleInterval 1 -MaxSamples 1).CounterSamples 
if ($couterSamples -ne $null) {
	$couterSamples | %{ [pscustomobject]@{ Path=$_.Path; Value=$_.Cookedvalue } } 
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

return [pscustomobject]@{PluginName = "PerfCounters"; FunctionName="GetPerfCounters"; GlobalConfig=$GlobalConfig; ModuleConfig=$ModuleConfig; NodeHostName=$NodeHostName; MetricPath=$MetricPath }




