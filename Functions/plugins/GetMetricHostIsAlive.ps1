function GetMetricHostIsAlive {
    param ( $pingResults )

     if ($pingResults -eq $null){
         $pingResults = @() } 

    $pingResults | ForEach-Object {         
    $HostMetric=$_.Host
    $ValueMetric=$_.Value
    [pscustomobject]@{Path="\\$HostMetric\IsAlive";Value="$ValueMetric"}

    [pscustomobject]@{Path="\\$HostMetric\$(($env:COMPUTERNAME).ToLower())\IsAlive";Value="$ValueMetric"}
    }

   }