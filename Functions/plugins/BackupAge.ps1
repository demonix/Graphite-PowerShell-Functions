Param(
    [Hashtable]$GlobalConfig,
    [System.Xml.XmlElement]$ModuleConfig
)


function GetBackupAge {
    Param ([System.Xml.XmlElement]$ModuleConfig)
    $lastBackupAgeHours = $null
    if (Get-Command 'Get-WBBackupSet' -ea SilentlyContinue) {
        #if ($latestBackup = Get-WBBackupSet | sort BackupTime -Descending | select -First 1) {
        #    $lastBackupAgeHours = ([datetime]::now - $latestBackup.BackupTime).TotalHours
        #}
        if ($bs = Get-WBSummary) {
            $bs = Get-WBSummary
            $fromSuccessfulToNextTimespan = ($bs.NextBackupTime - $bs.LastSuccessfulBackupTime)
            $fromLastToNextTimespan = ($bs.NextBackupTime - $bs.LastBackupTime)
            $lastBackupAgeHours = ($fromSuccessfulToNextTimespan - $fromLastToNextTimespan).TotalHours
        }
    }

    if ($lastBackupAgeHours -ne $null) {
        [pscustomobject]@{ 
            Path  ="\\$($env:COMPUTERNAME)\BackupAgeHours".ToLower(); 
            Value =  [math]::Round($lastBackupAgeHours,2)
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

return [pscustomobject]@{PluginName = "BackupAge"; FunctionName="GetBackupAge"; GlobalConfig=$GlobalConfig; ModuleConfig=$ModuleConfig; NodeHostName=$NodeHostName; MetricPath=$MetricPath }
