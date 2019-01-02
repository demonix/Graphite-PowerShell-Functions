New-Module `
-AsCustomObject `
-name PerfCountersModule `
-ScriptBlock { 

	function Init 
	{
		$plugin = [PSCustomObject]@{
			PluginName = "PerfCounters"
			Enabled = $false
			Config = $null
			MetricPath = ""
			NodeHostName = ""
			ConfigSectionName = "PerfCounters"
		}
	
		$getMetricsBlock = 
		{
			if (!($this.Enabled)) {return}
			(Get-Counter -Counter $this.Config.Counter.Name -SampleInterval 1 -MaxSamples 1).CounterSamples | %{ [pscustomobject]@{ Path=$_.Path; Value=$_.Cookedvalue } } 
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



