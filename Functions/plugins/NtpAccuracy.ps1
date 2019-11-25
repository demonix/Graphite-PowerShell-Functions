param([Hashtable]$GlobalConfig, [System.Xml.XmlElement]$ModuleConfig)


function GetNtpAccuracy {
param ([System.Xml.XmlElement]$ModuleConfig)

$ReferenceNtpTimeSource = $ModuleConfig.ReferenceNtpTimeSource
  
      $sample = & W32TM /stripchart /computer:$($ReferenceNtpTimeSource) /dataonly /period:1 /samples:1 2>&1 | Select-String '[+-]\d\d\.\d\d\d\d\d\d\d' -AllMatches | Foreach {$_.Matches} | Foreach {[decimal]$_.Value*1000}
	  [pscustomobject]@{ Path="\\$($env:COMPUTERNAME)\NtpOffsetMs".ToLower(); Value=$sample }
  
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

return [pscustomobject]@{PluginName = "NtpAccuracy"; FunctionName="GetNtpAccuracy"; GlobalConfig=$GlobalConfig; ModuleConfig=$ModuleConfig; NodeHostName=$NodeHostName; MetricPath=$MetricPath }
