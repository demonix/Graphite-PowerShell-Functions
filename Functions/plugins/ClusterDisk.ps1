New-Module `
-AsCustomObject `
-name ClusterPhysicalDiskPerfCountersModule `
-ScriptBlock { 

	function Init 
	{
		$plugin = [PSCustomObject]@{
			PluginName = "ClusterPhysicalDiskPerfCounters"
			Enabled = $false
			Config = $null
			MetricPath = ""
			NodeHostName = ""
			ConfigSectionName = "ClusterPhysicalDiskPerfCounters"
		}
	
		$getMetricsBlock = 
		{
		
			if (!($this.Enabled)) {return}
			#формирует словарь полный путь (с именем компа) до счетчика с цифровым номером диска -> счетчик с буковй диска
			#получает метрики по цифровому номеру, а наружу отдает с буквой диска
			
			$counterstoGet = Get-ClusterDiskCounters $this.Config.Counter.Name
						
			(Get-Counter -Counter @($counterstoGet.Keys) -SampleInterval 1 -MaxSamples 1).CounterSamples | %{ 
			
			[pscustomobject]@{ Path=$counterstoGet[$_.Path]; Value=$_.Cookedvalue } 
			} 
		}
	
		$memberParam = @{
			MemberType = "ScriptMethod"
			InputObject = $plugin
			Name = "GetMetrics"
			Value = $getMetricsBlock
		}
		Add-Member @memberParam
		return $plugin
	}
	
	function Get-ClusterDiskCounters {
	param (
        
        $countersToGet
    )
	
	
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
			$countersToGet| %{ $counterNames.add("\\$($env:COMPUTERNAME)\PhysicalDisk($diskNumber)\$($_)".toLower(), "\\$($env:COMPUTERNAME)\PhysicalDisk($diskName)\$($_)" )}}

	return 	$counterNames
		
		
	}
} 



