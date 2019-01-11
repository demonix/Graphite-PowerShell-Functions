New-Module `
-AsCustomObject `
-name Example `
-ScriptBlock { 

	function Init 
	{
		$plugin = [PSCustomObject]@{
			PluginName = "Example"
			Enabled = $false
			Config = $null
			MetricPath = ""
			NodeHostName = ""
			ConfigSectionName = "Example"
		}
	
		$getMetricsBlock = 
		{
			if (!($this.Enabled)) {return}
			
			[pscustomobject]@{ Path="$($this.NodeHostName).Example"; Value=1}
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
} 



