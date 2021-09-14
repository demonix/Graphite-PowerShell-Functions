param([Hashtable]$GlobalConfig, [System.Xml.XmlElement]$ModuleConfig)


function GetHostAliveAsync {
    param ([System.Xml.XmlElement]$ModuleConfig)
    $hosts = $ModuleConfig.Host.Name.ToLower();
    $pingResults=GetPingResultAsync -hosts $hosts
    GetMetricHostIsAlive -pingResults $pingResults
    }

function GetPingResultAsync {
    param ($hosts)
	$timeout = 300
	
    #Запускается асинхронный пинг до хостов		
	$tasks = $hosts | %{
        $task = [System.Net.NetworkInformation.Ping]::new().SendPingAsync($_,$timeout)
		[pscustomobject]@{ Host=$_; Task=$task }
	}
    
    #Ожидание завершения SendPingAsync и игнорирование ошибки резолвинга хоста
    Try {
        [System.Threading.Tasks.Task]::WaitAll($tasks.task)
    } 
    catch {
         Write-Warning ($_.exception.InnerException.InnerExceptions |%{$_.Message+" "+$_.InnerException.Message})
        }

    #Если хост не резолвится, то возвращается значение метрики IsAlive=0
    $faultedtask=$tasks | ? {($_.Task.IsFaulted )}
    $faultedtask | %{ 
        [pscustomobject]@{ Host=$_.Host; Value=0 }
    }
    #Переопределяем хосты, отбрасываем хосты, которые не резолвятся
    $tasks=$tasks | ? {($_.Task.IsFaulted -ne $true)}

    #Если пинг не отменен по таймауту и завершился успешно, то возвращется значение метрики IsAlive=1	            
    $tasks | ? { ($_.Task.IsCanceled -eq $false) -and ($_.Task.Result.Status -eq 'Success')}  | %{
           [pscustomobject]@{ Host=$_.Host; Value=1 }
    }

	#Запускается повтороный пинг для всех не успешных хостов 		
	$secondTasks = $tasks | ? { ($_.Task.IsCanceled) -or ($_.Task.Result.Status -ne 'Success')} | %{
			$secondTask = [System.Net.NetworkInformation.Ping]::new().SendPingAsync($_.Host,$timeout)
		[pscustomobject]@{ Host=$_.Host; Task=$secondTask }
	}
    Try {
        [System.Threading.Tasks.Task]::WaitAll($tasks.task)
    } 
    catch {
         Write-Warning ($_.exception.InnerException.InnerExceptions |%{$_.Message+" "+$_.InnerException.Message})
        }

    #Проверяется результат повторного пинга и возвращаются соответствующее значения метрик IsAlive
	$secondTasks | ? {($_.Task.IsCanceled -eq $false) -and ($_.Task.Result.Status -eq 'Success')} | %{
        [pscustomobject]@{ Host=$_.Host; Value=1 }
    }
	$secondTasks | ? {($_.Task.IsCanceled) -or ($_.Task.Result.Status -ne 'Success')}  | %{
        [pscustomobject]@{ Host=$_.Host; Value=0 }
    }			
}


function GetMetricHostIsAlive {
    param ( $pingResults )  
    $pingResults | ForEach-Object {         
    $HostMetric=$_.Host
    $ValueMetric=$_.Value
    [pscustomobject]@{Path="\\$HostMetric\IsAlive";Value="$ValueMetric"}

    [pscustomobject]@{Path="\\$HostMetric\$NodeHostName\IsAlive";Value="$ValueMetric"}
    }

   }


function GetHostAlive {
param ([System.Xml.XmlElement]$ModuleConfig)

$hosts = $ModuleConfig.Host.Name
			
			$Ping = [System.Net.NetworkInformation.Ping]::new()
			
			$hosts | %{
			   $pingReply = $null
			   try {
			      $pingReply = $Ping.Send($_,300)
			      if ($pingReply.Status -ne 'Success')
			      {
			       Start-Sleep -Milliseconds 300
				   $pingReply = $Ping.Send($_,300)
			      }
				  $isAlive = $pingReply.Status -eq 'Success'
			   }
			   catch {
			   Write-Host "ERROR in Ping: $_"
			   $isAlive = $false
			   }
			   [pscustomobject]@{ Path="\\$($_)\IsAlive"; Value=[int]$isAlive }
			}
			
}

$MetricPath = $GlobalConfig.MetricPath
$NodeHostName = $GlobalConfig.NodeHostName.ToLower();

if ($ModuleConfig.HasAttribute("CustomPrefix"))
{
	$MetricPath = $ModuleConfig.GetAttribute("CustomPrefix")
}
if ($ModuleConfig.HasAttribute("CustomNodeHostName"))
{
	$NodeHostName = $ModuleConfig.GetAttribute("CustomNodeHostName")
}

return [pscustomobject]@{PluginName = "HostAlive"; FunctionName="GetHostAliveAsync"; GlobalConfig=$GlobalConfig; ModuleConfig=$ModuleConfig; NodeHostName=$NodeHostName; MetricPath=$MetricPath }
