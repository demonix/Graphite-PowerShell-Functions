param([Hashtable]$GlobalConfig, [System.Xml.XmlElement]$ModuleConfig)

function Get-ClusterDiskCountersList {
	param (
        
        $countersToGet
    )
	
	   $clusterName = (Get-Cluster).name
       $clusterDisks = Get-WmiObject -namespace root\MSCluster MSCluster_Resource -filter "Type='Physical Disk'"
	   #if (($clusterDisks.length -gt 0) -and !($clusterDisks[0].OwnerNode))
	   if (($clusterDisks.length -gt 0) -and !(Get-Member -inputobject $clusterDisks[0] -name "OwnerNode" -Membertype Properties))
	   {
	   $clusterDisks | %{ $OwnerNode =  (gwmi -namespace "root\mscluster" -Authentication PacketPrivacy -query "ASSOCIATORS OF {MSCluster_Resource.Name='$($_.Name)'} WHERE AssocClass = MSCluster_NodeToActiveResource").Name ; 
	   $_  | add-member -pass NoteProperty OwnerNode $OwnerNode} | out-null
	   }
	      

        $diskNumberToNameMapping = $clusterDisks | ? {$_.OwnerNode -eq $env:computername } | %{
		$diskName = $_.name; 
		$disk = $_.GetRelated("MSCluster_Disk") | select -first 1; 

		$partition = $_.GetRelated("MSCluster_Disk")| select -first 1 | %{$_.GetRelated("MSCluster_DiskPartition")};
		
		$diskNumber = if ($partition.FileSystem -eq "CSVFS") {$disk.Name} else {"$($disk.Name) $($partition.Path)"};
		New-Object -TypeName psobject -Property @{DiskNumber = $diskNumber; DiskName=$diskName}}
       
			[hashtable] $counterNames = @{}
			$diskNumberToNameMapping| %{
			$diskNumber = $_.DiskNumber; 
			$diskName = $_.DiskName -replace "\)", "_"; 
			$diskName = $diskName -replace "\(", "_"; 
			$countersToGet| %{ $counterNames.add("\\$($env:COMPUTERNAME)\PhysicalDisk($diskNumber)\$($_)".toLower(), "\\$($clusterName)\$($env:COMPUTERNAME)\PhysicalDisk($diskName)\$($_)" )}}

	return 	$counterNames
		
		
}
	
function GetClusterPhysicalDiskPerfCounters {
param ([System.Xml.XmlElement]$ModuleConfig)

$counterstoGet = Get-ClusterDiskCountersList $ModuleConfig.Counter.Name
						
			$couterSamples = (Get-Counter -Counter @($counterstoGet.Keys) -SampleInterval 1 -MaxSamples 1).CounterSamples
			if ($couterSamples -ne $null) {
				$couterSamples | %{ 
				
				[pscustomobject]@{ Path=$counterstoGet[$_.Path]; Value=$_.Cookedvalue } 
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

return [pscustomobject]@{PluginName = "ClusterPhysicalDiskPerfCounters"; FunctionName="GetClusterPhysicalDiskPerfCounters"; GlobalConfig=$GlobalConfig; ModuleConfig=$ModuleConfig; NodeHostName=$NodeHostName; MetricPath=$MetricPath }







