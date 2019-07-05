param([Hashtable]$GlobalConfig, [System.Xml.XmlElement]$ModuleConfig)

function GetHostAliveAsync {
param ([System.Xml.XmlElement]$ModuleConfig)

$hosts = $ModuleConfig.Host.Name
			$timeout = 300
			
			
			$tasks = $hosts | %{
			   $task = [System.Net.NetworkInformation.Ping]::new().SendPingAsync($_,$timeout)
			   [pscustomobject]@{ Host=$_; Task=$task }
			}
			Start-Sleep -Milliseconds ($timeout*2)
			
			$tasks | ? { ($_.Task.IsCanceled -eq $false) -and ($_.Task.Result.Status -eq 'Success')}  | %{[pscustomobject]@{ Path="\\$($_.Host)\IsAlive"; Value=1 }}
			
			$secondTasks = $tasks | ? {($_.Task.IsCanceled) -or ($_.Task.Result.Status -ne 'Success')} | %{
				 $secondTask = [System.Net.NetworkInformation.Ping]::new().SendPingAsync($_.Host,$timeout)
			   [pscustomobject]@{ Host=$_.Host; Task=$secondTask }
			}
			Start-Sleep -Milliseconds ($timeout*2)
			$secondTasks | ? {($_.Task.IsCanceled -eq $false) -and ($_.Task.Result.Status -eq 'Success')}  | %{[pscustomobject]@{ Path="\\$($_.Host)\IsAlive"; Value=1 }}
			$secondTasks | ? {($_.Task.IsCanceled) -or ($_.Task.Result.Status -ne 'Success')}  | %{[pscustomobject]@{ Path="\\$($_.Host)\IsAlive"; Value=0 }}
		
			
}

function GetHostAlive {
param ([System.Xml.XmlElement]$ModuleConfig)

$hosts = $ModuleConfig.Host.Name
			
			$Ping = [System.Net.NetworkInformation.Ping]::new()
			
			$hosts | %{
			
			   $pingReply = $Ping.Send($_,300)
			   if ($pingReply.Status -ne 'Success')
			   {
			    Start-Sleep -Milliseconds 300
				$pingReply = $Ping.Send($_,300)
			   }
			   
			   $isAlive = $pingReply.Status -eq 'Success'
			   [pscustomobject]@{ Path="\\$($_)\IsAlive"; Value=[int]$isAlive }
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

return [pscustomobject]@{PluginName = "HostAlive"; FunctionName="GetHostAliveAsync"; GlobalConfig=$GlobalConfig; ModuleConfig=$ModuleConfig; NodeHostName=$NodeHostName; MetricPath=$MetricPath }
