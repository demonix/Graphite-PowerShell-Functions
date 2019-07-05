param([Hashtable]$GlobalConfig, [System.Xml.XmlElement]$ModuleConfig)



	function Get-CloudUsageInfo {
	param(
		
		$CpuOvercommitRatio,
		$VmmServerName
		)
	
	$cpuOvercommitRatio = 4
	Get-SCVMMServer $vmmServerName| out-null
	$alluserRoles = Get-SCUserRole
	$allVms = Get-SCVirtualMachine
	
	$r = Get-SCCloud   | %{$cloud = $_; $users = $alluserRoles | ? Profile -ne "Administrator" |? Profile -ne "ReadOnlyAdmin"  | ? cloud -contains $cloud; $users | %{
	
	$user = $_; 
    $usage = New-Object psobject
	
	$userVms = $allVms |  ? UserRole -eq $user | ? Cloud -eq $cloud
	$runningUserVms = $userVms | ? Status -eq Running
	if ($runningUserVms -eq $null) {$runningUserVmsCount = 0} else {$runningUserVmsCount = ($runningUserVms | measure ).Count}
	$notRunningUserVms = $userVms | ? Status -ne Running
	if ($notRunningUserVms -eq $null) {$notRunningUserVmsCount = 0} else {$notRunningUserVmsCount = ($notRunningUserVms | measure ).Count}
	
	if ($userVms -eq $null) {$StorageCurrentGB = 0}
	else {
	$StorageCurrentGB = ($userVms| measure -sum TotalSize).Sum / 1Gb
	}
	
	if ($runningUserVms -eq $null) {
	$MemoryUsageMB = 0
	$CPUUsageCount = 0
	$StorageCurrentGB +=0
	}
	else {
	$MemoryUsageMB = ($runningUserVms| measure -sum Memory).Sum 
	$CPUUsageCount = ($runningUserVms| measure -sum CPUCount).Sum
	$StorageCurrentGB += ($runningUserVms | ? StopAction -eq SaveVm | measure -sum Memory).Sum * 1Mb / 1Gb
	}
	
	
	if ($CPUUsageCount -eq $null) { $CPUUsageCount = 0}
	if ($MemoryUsageMB -eq $null) { $MemoryUsageMB = 0}
	if ($StorageCurrentGB -eq $null) { $StorageCurrentGB = 0}
	
	$usage | Add-Member -NotePropertyName RunningVms -NotePropertyValue $runningUserVmsCount; 
	$usage | Add-Member -NotePropertyName NotRunningVms -NotePropertyValue $notRunningUserVmsCount;
	$usage | Add-Member -NotePropertyName CPUUsageCount -NotePropertyValue $CPUUsageCount; 
	$usage | Add-Member -NotePropertyName MemoryUsageMB -NotePropertyValue $MemoryUsageMB;
	$usage | Add-Member -NotePropertyName StorageCurrentGB -NotePropertyValue ( [math]::Round($StorageCurrentGB,2));
	
	
	
	$cloudHostgroup = $cloud.Hostgroup;
	$cloudHosts=$cloudHostgroup.AllChildHosts;
	
	
	
	$totalMemoryMb = ($cloudHosts | measure -Sum  TotalMemory).Sum / 1Mb;
	$totalMemoryReserveMb = ($cloudHosts | measure -Sum  MemoryReserveMB).Sum;
	$totalCores = ($cloudHosts | measure -Sum  LogicalProcessorCount).Sum;
	
	$storageUsagePercent = 0
	$cloudType = ""
	$isStandardCloud = ($cloudHosts | %{$_.RegisteredStorageFileShares} | Select-Object -Unique | measure -Sum Capacity) -ne $null
	
	if ($isStandardCloud) {
	$totalStandardStorageCapacity = ($cloudHosts | %{$_.RegisteredStorageFileShares} | Select-Object -Unique | measure -Sum Capacity).Sum;
	$storageUsagePercent = ($usage.StorageCurrentGB/($totalStandardStorageCapacity/1Gb))*100;
	$cloudType = "Standard"
	}
	else {
	$tmp = ($cloudHosts | %{$_.DiskVolumes | ? IsAvailableForPlacement -eq $true } | measure -Sum Capacity)
	if ($tmp -eq $null) {$totalLoadStorageCapacity = 0} else {$totalLoadStorageCapacity = $tmp.Sum;}
	$storageUsagePercent = ($usage.StorageCurrentGB/($totalLoadStorageCapacity/1Gb))*100;
	$cloudType = "Load"
	}
	
	$cpuUsagePercent = ($usage.CPUUsageCount/($totalCores*$cpuOvercommitRatio))*100;
	$memoryUsagePercent = ($usage.MemoryUsageMB /($totalMemoryMb - $totalMemoryReserveMb))*100;
	$maxUsage = (($cpuUsagePercent, $memoryUsagePercent, $storageUsagePercent) | measure -Max ).Maximum
	
	$cloudDescription = ""
	if ($cloudType -eq "Load") {
	$cloudDescription =  $cloud.Description + " (Нагрузочное)"
	}
	else {
		$cloudDescription =  $cloud.Description + " (Функциональное)"
	}
	
	
	
	
	$usage | Add-Member -NotePropertyName CloudName -NotePropertyValue $cloud.Name; 
	$usage | Add-Member -NotePropertyName CloudDescription -NotePropertyValue $cloudDescription;
	$usage | Add-Member -NotePropertyName CpuUsagePercent -NotePropertyValue ( [math]::Round($cpuUsagePercent,2));
	$usage | Add-Member -NotePropertyName MemoryUsagePercent -NotePropertyValue ( [math]::Round($memoryUsagePercent,2));
	$usage | Add-Member -NotePropertyName StorageUsagePercent -NotePropertyValue ( [math]::Round($storageUsagePercent,2));
	$usage | Add-Member -NotePropertyName MaxUsage -NotePropertyValue ( [math]::Round($maxUsage,2));
	$usage | Add-Member -NotePropertyName CloudType -NotePropertyValue $cloudType;
	
	if ($user.Name.Length -ge 37) {
		$userName = $user.Name.Substring(0, $user.Name.Length-37);
	}
	if ($userName -NotLike "*@skbkontur.ru") {
		$userName = ""
	}
	
	$usage | Add-Member -NotePropertyName UserName -NotePropertyValue $userName;
	
	$usage }} 
	
	
	
	
	
	
	$cloudHostgroup = Get-scvmhostgroup 'Standard Testing';
	$cloudHosts=$cloudHostgroup.AllChildHosts;

    [long]$totalStandardLocalStorageCapacity = ($cloudHosts | %{$_.DiskVolumes | ? IsAvailableForPlacement -eq $true } | measure -Sum Capacity).Sum;
	[long]$totalStandardClusterStorageCapacity = ($cloudHosts | %{$_.RegisteredStorageFileShares} | Select-Object -Unique | measure -Sum Capacity).Sum;
	$totalStandardStorageCapacity = $totalStandardClusterStorageCapacity + $totalStandardLocalStorageCapacity
	$totalMemoryMb = ($cloudHosts | measure -Sum  TotalMemory).Sum / 1Mb;
	$totalMemoryReserveMb = ($cloudHosts | measure -Sum  MemoryReserveMB).Sum;
	$totalCores = ($cloudHosts | measure -Sum  LogicalProcessorCount).Sum;
	
	$TotalCPUUsageCount = ($r | ? CloudType -eq "Standard" | measure -sum CPUUsageCount).Sum
	$TotalMemoryUsageMB = ($r | ? CloudType -eq "Standard" | measure -sum MemoryUsageMB).Sum
	$StorageCurrentGB =   ($r | ? CloudType -eq "Standard" | measure -sum StorageCurrentGB).Sum
	
	
	
	$cpuUsagePercent = ($TotalCPUUsageCount/($totalCores*$cpuOvercommitRatio))*100;
	$memoryUsagePercent = ($TotalMemoryUsageMB /($totalMemoryMb - $totalMemoryReserveMb))*100;
	$storageUsagePercent = ($StorageCurrentGB/($totalStandardStorageCapacity/1Gb))*100;
	
	$totalUsage= New-Object psobject
	$totalUsage | Add-Member -NotePropertyName type -NotePropertyValue "Standard"; 
	$totalUsage | Add-Member -NotePropertyName cpuUsagePercent -NotePropertyValue ( [math]::Round( $cpuUsagePercent,2)); 
	$totalUsage | Add-Member -NotePropertyName memoryUsagePercent -NotePropertyValue ( [math]::Round($memoryUsagePercent,2)); 
	$totalUsage | Add-Member -NotePropertyName storageUsagePercent -NotePropertyValue ( [math]::Round($storageUsagePercent,2)); 
	
	
	
	$standardTotalUsage = $totalUsage 
	
	
	$cloudHostgroup = Get-scvmhostgroup "Fast SSD";
	$cloudHosts=$cloudHostgroup.AllChildHosts;
	
	$totalLoadStorageCapacity = ($cloudHosts | %{$_.DiskVolumes | ? IsAvailableForPlacement -eq $true } | measure -Sum Capacity).Sum;
	$totalMemoryMb = ($cloudHosts | measure -Sum  TotalMemory).Sum / 1Mb;
	$totalMemoryReserveMb = ($cloudHosts | measure -Sum  MemoryReserveMB).Sum;
	$totalCores = ($cloudHosts | measure -Sum  LogicalProcessorCount).Sum;
	
	
	
	$TotalCPUUsageCount = ($r | ? CloudType -eq "Load" | measure -sum CPUUsageCount).Sum
	$TotalMemoryUsageMB = ($r | ? CloudType -eq "Load" | measure -sum MemoryUsageMB).Sum
	$StorageCurrentGB =   ($r | ? CloudType -eq "Load" | measure -sum StorageCurrentGB).Sum
	
	
	
	$cpuUsagePercent = ($TotalCPUUsageCount/($totalCores*$cpuOvercommitRatio))*100;
	$memoryUsagePercent = ($TotalMemoryUsageMB /($totalMemoryMb - $totalMemoryReserveMb))*100;
	
	$storageUsagePercent = ($StorageCurrentGB/($totalLoadStorageCapacity/1Gb))*100;
	
	$totalUsage= New-Object psobject
	$totalUsage | Add-Member -NotePropertyName type -NotePropertyValue "Load"; 
	$totalUsage | Add-Member -NotePropertyName cpuUsagePercent -NotePropertyValue ( [math]::Round( $cpuUsagePercent,2)); 
	$totalUsage | Add-Member -NotePropertyName memoryUsagePercent -NotePropertyValue ( [math]::Round($memoryUsagePercent,2)); 
	$totalUsage | Add-Member -NotePropertyName storageUsagePercent -NotePropertyValue ( [math]::Round($storageUsagePercent,2)); 
	
	$loadTotalUsage = $totalUsage 
	
	$results = New-Object psobject
	
	$perCloud = $r | select CloudDescription, CloudName, UserName, RunningVms, NotRunningVms, CPUUsageCount, CpuUsagePercent, MemoryUsageMB, MemoryUsagePercent, StorageCurrentGB, StorageUsagePercent, MaxUsage | sort cloudType, cloudname, username
	
	
	$results | Add-Member -NotePropertyName PerCloudStats -NotePropertyValue $perCloud; 
	$results | Add-Member -NotePropertyName TotalUsageStats -NotePropertyValue @($loadTotalUsage, $standardTotalUsage)
	return $results
	}
	
	
	
function GetVMMCloudUsage {
param ([System.Xml.XmlElement]$ModuleConfig)
			
$cui = Get-CloudUsageInfo -CpuOvercommitRatio $ModuleConfig.CpuOvercommitRatio.Value  -VmmServerName $ModuleConfig.VmmServer.Name
			$cui.PerCloudStats | %{
				$CloudName = $_.CloudName
				if ($CloudName -eq 'Simple-Cloud')
					{$CloudName += "-"+$_.UserName.Replace("@skbkontur.ru", "")}
					$CloudName = $CloudName.Replace(".", "-")
					[pscustomobject]@{ Path=  "{0}.RunningVms" -f $CloudName ; Value=$_.RunningVms}
					[pscustomobject]@{ Path=  "{0}.CPUUsageCount" -f $CloudName ; Value=$_.CPUUsageCount}
					[pscustomobject]@{ Path=  "{0}.CpuUsagePercent" -f $CloudName ; Value=$_.CpuUsagePercent}
					[pscustomobject]@{ Path=  "{0}.MemoryUsageMB" -f $CloudName ; Value=$_.MemoryUsageMB}
					[pscustomobject]@{ Path=  "{0}.MemoryUsagePercent" -f $CloudName ; Value=$_.MemoryUsagePercent}
					[pscustomobject]@{ Path=  "{0}.StorageCurrentGB" -f $CloudName ; Value=$_.StorageCurrentGB}
					[pscustomobject]@{ Path=  "{0}.StorageUsagePercent" -f $CloudName ; Value=$_.StorageUsagePercent}
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

return [pscustomobject]@{PluginName = "VMMCloudUsage"; FunctionName="GetVMMCloudUsage"; GlobalConfig=$GlobalConfig; ModuleConfig=$ModuleConfig; NodeHostName=$NodeHostName; MetricPath=$MetricPath }
