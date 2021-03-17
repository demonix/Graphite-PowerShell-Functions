Param(
    [Hashtable]$GlobalConfig,
    [System.Xml.XmlElement]$ModuleConfig
)


function GetAdBackupAge {
    Param ([System.Xml.XmlElement]$ModuleConfig)
    $lastBackupAgeHours = $null

    try {
        [string]$dnsRoot = (Get-ADDomain).DNSRoot
        [string[]]$Partitions = (Get-ADRootDSE).namingContexts
        $contextType = [System.DirectoryServices.ActiveDirectory.DirectoryContextType]::DirectoryServer
        $context = new-object System.DirectoryServices.ActiveDirectory.DirectoryContext($contextType,$env:COMPUTERNAME)
        $domainController = [System.DirectoryServices.ActiveDirectory.DomainController]::GetDomainController($context)
    
        ForEach($partition in $partitions)
        {
           $domainControllerMetadata = $domainController.GetReplicationMetadata($partition)
           $dsaSignature = $domainControllerMetadata.Item("dsaSignature")
      
           if ($partition -match "(DC\=|CN\=)+(.*?),") {
               $partitionName = $($Matches[2])
               $lastAdBackupAgeHours = [math]::Round(([datetime]::Now - $dsaSignature.LastOriginatingChangeTime).TotalHours,2)

               #Write-Host "$($env:COMPUTERNAME)\$partitionName: $($Matches[2]) was backed up $sample hours ago`n"       

                if ($partitionName -and $lastAdBackupAgeHours) {
                    [pscustomobject]@{ 
                        Path  ="\\$($env:COMPUTERNAME)\AdBackupAgeHours.$partitionName".ToLower(); 
                        Value =  [math]::Round($lastAdBackupAgeHours,2)
                    }
                }
           }
        }
    } catch {
        Write-Warning ($_ | select * | Out-String)
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

return [pscustomobject]@{PluginName = "AdBackupAge"; FunctionName="GetAdBackupAge"; GlobalConfig=$GlobalConfig; ModuleConfig=$ModuleConfig; NodeHostName=$NodeHostName; MetricPath=$MetricPath }
