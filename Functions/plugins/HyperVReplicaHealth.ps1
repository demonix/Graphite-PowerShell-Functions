param([Hashtable]$GlobalConfig, [System.Xml.XmlElement]$ModuleConfig)

function GetHyperVReplicaHealth () {
    $ReplicatedVMs = @()
    $ReplicatedVMs += Get-WmiObject -Namespace "root\virtualization\v2" -Class "Msvm_ComputerSystem" -Filter "Caption='Virtual Machine'" | ? ReplicationMode -eq 1 
    if($ReplicatedVMs){
        $ReplicatedVMs | % {
            $ReplicatedVM = $_
            if($ReplicatedVM){
                [pscustomobject]@{ Path="\\$($env:computername.ToLower())\HvReplica\SourceVM\$($ReplicatedVM.ElementName.tolower())\Health"; Value=$ReplicatedVM.ReplicationHealth }
            }
        }
    }
    $ReplicaVMs = @()
    $ReplicaVMs += Get-WmiObject -Namespace "root\virtualization\v2" -Class "Msvm_ComputerSystem" -Filter "Caption='Virtual Machine'" | ? ReplicationMode -eq 2 
    if($ReplicaVMs){
        $ReplicaVMs | % {
            $ReplicaVM = $_
            if($ReplicaVM){
                [pscustomobject]@{ Path="\\$($env:computername.ToLower())\HvReplica\ReplicaVM\$($ReplicaVM.ElementName.tolower())\Health"; Value=$ReplicaVM.ReplicationHealth }
            }
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

return [pscustomobject]@{PluginName = "HyperVReplicaHealth"; FunctionName="GetHyperVReplicaHealth"; GlobalConfig=$GlobalConfig; ModuleConfig=$ModuleConfig; NodeHostName=$NodeHostName; MetricPath=$MetricPath }


