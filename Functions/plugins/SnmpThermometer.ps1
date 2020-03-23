param([Hashtable]$GlobalConfig, [System.Xml.XmlElement]$ModuleConfig)


function GetSnmpTemperature {
param ([System.Xml.XmlElement]$ModuleConfig)

if ((get-module -ListAvailable SNMP) -eq $null) {
Write-Host "SNMP module not installed"
return 
}

$sensors = $ModuleConfig.Sensor
$sensors | %{
$sensor = $_
try {
	$community = $ModuleConfig.Auth.Community
	if ($ModuleConfig.Auth.Community.StartsWith('$env:')) {
		$community = [environment]::GetEnvironmentVariable($ModuleConfig.Auth.Community.TrimStart('$env:'))
	}
	$snmpData = Get-SnmpData -IP $sensor.Host -Community $community -OID '1.3.6.1.4.1.40418.2.2.4.1.0'
	[pscustomobject]@{ Path=$sensor.Name; Value=$snmpData.Data}
	}
 catch {
	Write-Host "ERROR in GetSnmpTemperatureCounters: $_"
	[pscustomobject]@{ Path=$sensor.Name; Value=-100500}
}
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

return [pscustomobject]@{PluginName = "SnmpTempermometer"; FunctionName="GetSnmpTemperature"; GlobalConfig=$GlobalConfig; ModuleConfig=$ModuleConfig; NodeHostName=$NodeHostName; MetricPath=$MetricPath }




