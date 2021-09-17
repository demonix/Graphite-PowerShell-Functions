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
        if ($_.exception.InnerException -is [System.AggregateException]) {
                 $_.exception.InnerException.InnerExceptions |%{$_.Message+" "+$_.InnerException.Message} | Write-Warning
                    } else {
                         $_.exception.message | Write-Warning
                }
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


    #Ожидание завершения повторного SendPingAsync и игнорирование ошибки резолвинга хоста
    Try {
        [System.Threading.Tasks.Task]::WaitAll($secondTasks.task)
      } 
    catch {
           # $_.exception.InnerException.InnerExceptions |%{$_.Message+" "+$_.InnerException.Message} | Write-Warning
           if ($_.exception.InnerException -is [System.AggregateException]) {
               $_.exception.InnerException.InnerExceptions |%{$_.Message+" "+$_.InnerException.Message} | Write-Warning
                    } else {
                         $_.exception.message | Write-Warning
                }
        }

    #Проверяется результат повторного пинга и возвращаются соответствующее значения метрик IsAlive
	$secondTasks | ? {($_.Task.IsCanceled -eq $false) -and ($_.Task.Result.Status -eq 'Success')} | %{
        [pscustomobject]@{ Host=$_.Host; Value=1 }
    }
	$secondTasks | ? {($_.Task.IsCanceled) -or ($_.Task.Result.Status -ne 'Success')}  | %{
        [pscustomobject]@{ Host=$_.Host; Value=0 }
    }			
}