New-Module `
-AsCustomObject `
-name VMMHost `
-ScriptBlock { 

	function Init 
	{
		$plugin = [PSCustomObject]@{
			PluginName = "VMMHost"
			Enabled = $false
			Config = $null
			MetricPath = ""
			NodeHostName = ""
			ConfigSectionName = "VMMHost"
		}
	
		$getMetricsBlock = 
		{
			if (!($this.Enabled)) {return}
			$vmmHosts = Get-SCVMHost -VMMServer $this.Config.VmmServer
			$Ping = [System.Net.NetworkInformation.Ping]::new()
			$vmmHosts | %{
			   $pingReply = $Ping.Send($_.fqdn,150)
			   $isAlive = $pingReply.Status -eq Success
			   [pscustomobject]@{ Path="\\$($_.ComputerName)\IsAlive"; Value=[int]$isAlive }
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
} 





