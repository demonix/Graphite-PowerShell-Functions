New-Module `
-AsCustomObject `
-name FailoverDhcpStats `
-ScriptBlock { 

	function Init 
	{
		$plugin = [PSCustomObject]@{
			PluginName = "FailoverDhcpStats"
			Enabled = $false
			Config = $null
			MetricPath = ""
			NodeHostName = ""
			ConfigSectionName = "FailoverDhcpStats"
		}
	
		$getMetricsBlock = 
		{
		
			if (!($this.Enabled)) {return}
			Get-DhcpStats 
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
	
	function Get-DhcpStats {
		$failover = Get-DhcpServerv4Failover 
		
		$primaryServer = $failover.PrimaryServerName.Split(".")[0].tolower().Replace('\','-').Replace('.','-')
		$secondaryServer = $failover.SecondaryServerName.Split(".")[0].tolower().Replace('\','-').Replace('.','-')
		$thisServer = 'unknown'
		$isServerPrimary = $failover.ServerType -eq 'PrimaryServer'
		if ($isServerPrimary)
		{$thisServer = $primaryServer }
		else
		{$thisServer = $secondaryServer }
		
		$partnerServer = $failover.PartnerServer.Split(".")[0].tolower().Replace('\','-').Replace('.','-')
		
		$failoverName = "$($primaryServer)-$($secondaryServer)"
		
		$failoverHealhty = $false
		
		switch ( $failover.State)
			{
				NoState { $failoverHealhty = $true}
				Normal { $failoverHealhty = $true}
				Init { $failoverHealhty = $false}
				CommunicationInterrupted { $failoverHealhty = $false}
				PartnerDown { $failoverHealhty = $false}
				PotentialConflict { $failoverHealhty = $false}
				Startup { $failoverHealhty = $false}
				ResolutionInterrupted { $failoverHealhty = $false}
				ConflictDone { $failoverHealhty = $false}
				Recover { $failoverHealhty = $false}
				RecoverWait { $failoverHealhty = $false}
				RecoverDone { $failoverHealhty = $false}
			}
			
		New-Object PSObject -Property @{Path = "$failoverName.scope-wide.failover-healthy.$thisServer"; Value = [int]$failoverHealhty}
		
		if ($isServerPrimary) {
			Get-DhcpServerv4Scope  |% {
			$scope = $_
			$scopeName = $scope.Name.Replace('\','-').Replace('.','-')
			$stats = Get-DhcpServerv4ScopeStatistics -ScopeId $scope.ScopeId -Failover 
			
			New-Object PSObject -Property @{Path = "$failoverName.$scopeName.totals.addreses-free"; Value = $stats.AddressesFree}
			
			New-Object PSObject -Property @{Path = "$failoverName.$scopeName.totals.addreses-in-use"; Value = $stats.AddressesInUse}
			New-Object PSObject -Property @{Path = "$failoverName.$scopeName.totals.pending-offers"; Value = $stats.PendingOffers}
			New-Object PSObject -Property @{Path = "$failoverName.$scopeName.totals.reserved-addresses"; Value = $stats.ReservedAddress}
			New-Object PSObject -Property @{Path = "$failoverName.$scopeName.totals.percent-in-use"; Value = $stats.PercentageInUse}
					
			New-Object PSObject -Property @{Path = "$failoverName.$scopeName.per-server.$primaryServer.addreses-free"; Value = $stats.AddressesFreeOnThisServer}
			New-Object PSObject -Property @{Path = "$failoverName.$scopeName.per-server.$primaryServer.addreses-in-use"; Value = $stats.AddressesInUseOnThisServer}
					
			New-Object PSObject -Property @{Path = "$failoverName.$scopeName.per-server.$secondaryServer.addreses-free"; Value = $stats.AddressesFreeOnPartnerServer}
			New-Object PSObject -Property @{Path = "$failoverName.$scopeName.per-server.$secondaryServer.addreses-in-use"; Value = $stats.AddressesInUseOnPartnerServer}
			}
		}
	
	}
		
} 







