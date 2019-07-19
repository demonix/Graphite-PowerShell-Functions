param([Hashtable]$GlobalConfig, [System.Xml.XmlElement]$ModuleConfig)

function Get-WUStatRequiredUpdates {
    Param(
        [Microsoft.UpdateServices.Internal.BaseApi.ComputerTarget] $computerObject
    )
    ## get all updates for computer
    $updates = $computerObject.GetUpdateInstallationInfoPerUpdate()
    $updates = $computerObject.GetUpdateInstallationInfoPerUpdate($updatescope)

    ## filter list for required and aprooved updates
    $requiredUpdates = $updates.GetEnumerator() | ? {
            $_.UpdateInstallationState -eq [Microsoft.UpdateServices.Administration.UpdateInstallationState]::NotInstalled `
        }  | ? {
            $_.UpdateApprovalAction -eq [Microsoft.UpdateServices.Administration.UpdateApprovalAction]::Install `
            -or `
            $_.UpdateApprovalAction -eq [Microsoft.UpdateServices.Administration.UpdateApprovalAction]::All
        } 
    
    #return $requiredUpdates
    $requiredUpdates | % {                
        $wsus.GetUpdate([guid]$_.UpdateId)#.CreationDate
    }
}


function Get-WUStatLastInstalledUpdateDate {
    Param(
        [Microsoft.UpdateServices.Internal.BaseApi.ComputerTarget] $computerObject
    )
    ## get all updates for computer
    $updates = $computerObject.GetUpdateInstallationInfoPerUpdate($updatescope)

    ## filter list for installed
    $installedUpdates = $updates.GetEnumerator() | ? {
            $_.UpdateInstallationState -eq [Microsoft.UpdateServices.Administration.UpdateInstallationState]::Installed `
            -or `
            $_.UpdateInstallationState -eq [Microsoft.UpdateServices.Administration.UpdateInstallationState]::InstalledPendingReboot
        }
            
    $installedUpdates | % {                
        #$wsus.GetUpdate([guid]$_.UpdateId).CreationDate        
        $updatesCache[$_.UpdateId.Guid]        
    } | sort | select -Last 1
    
    #return $requiredUpdates
}


function GetWsusUpdateStats {
    Param (
        [System.Xml.XmlElement]$ModuleConfig
    )

    #Param ($wsusServerDnsName = 'vm-wsus', $wsusServerPortNum = 8530)
    $wsusServerDnsName = $ModuleConfig.WsusServer.Name #'vm-wsus'
    $wsusServerPortNum = $ModuleConfig.WsusServer.Port #8530    
    $skipComputerThatNotReportedMonths = $ModuleConfig.skipComputerThatNotReported.Months

    $adDomainNames = $ModuleConfig.AdDomainIntergation.AdDomain.Name | ? { $_ }
    $adComputers = @{}
    
    $adDomainNames | %{ Get-ADComputer -Server $_ -Properties division -filter * | ? dnshostname -ne $null | select DNSHostName, division } | %{
        $adComputers.Add($_.DNSHostName.Tolower(), $_.division)
    }
 
    $wsus = Get-WsusServer $wsusServerDnsName -PortNumber $wsusServerPortNum

    $updatescope = New-Object Microsoft.UpdateServices.Administration.UpdateScope
    ## critical updates
    $criticalUpdatesClassificationId = [guid]'e6cf1350-c01b-414d-a61f-263d14d133b4'
    ## security updates
    $securityUpdatesClassificationId = [guid]'0fa1201d-4330-4fa8-8ae9-b877473b6441'

    $updatescope.Classifications.Clear()
    $updatescope.Classifications.Add($wsus.GetUpdateClassification($criticalUpdatesClassificationId)) | Out-Null
    $updatescope.Classifications.Add($wsus.GetUpdateClassification($securityUpdatesClassificationId)) | Out-Null

    ## cache updates info
    $updatesCache = @{}
    #$wsus.GetUpdates() | % {$updatesCache[$_.id.UpdateId.Guid] = $_.CreationDate}
    $wsus.GetUpdates($updatescope) | % {$updatesCache[$_.id.UpdateId.Guid] = $_.CreationDate}

    ## get computers list
    $computerscope = New-Object Microsoft.UpdateServices.Administration.ComputerTargetScope
    $computerscope.FromLastReportedStatusTime = ([datetime]::Now).AddMonths(-$skipComputerThatNotReportedMonths)
    #$computers = $wsus.GetComputerTargets()
    $computers = $wsus.GetComputerTargets($computerscope)



    ## init vars
    #$sw = [System.Diagnostics.Stopwatch]::new()
    $currentNum = 0
    $totalComputers = $computers.Count


    $result = $computers.GetEnumerator() | % {
        $currentNum++
        $computer = $_
        $compName = $computer.FullDomainName        
        ## compute progress
        $i = [int](($currentNum/$totalComputers)*100)
        Write-Progress -Activity "Data in Progress" -Status "$currentNum of $totalComputers Complete:" -PercentComplete $i
        #$sw.Start()
    
        ## get last installed patch date for computer
        $lastInstalledUpdateDate = Get-WUStatLastInstalledUpdateDate -computerObject $computer

        #$sw.Stop(); Write-Warning $sw.ElapsedMilliseconds; $sw.Reset()
    
        ## return result
        [pscustomobject]@{
            computerName = $compName
            latestInstalledUpdate = $lastInstalledUpdateDate
        }
    
    }

    ## define time spans
    
    $lastMonth = ([datetime]::Now).AddMonths(-1)
    $lastTwoMonth = ([datetime]::Now).AddMonths(-2)
    $lastThreeMonth = ([datetime]::Now).AddMonths(-3)
    $lastSixMonth = ([datetime]::Now).AddMonths(-6)
    $lastOneYear = ([datetime]::Now).AddYears(-1)
    $lastTwoYear = ([datetime]::Now).AddYears(-2)



    ## aggregate data: compute statistics
    $stats = @{}
    $stats["last-1-Month"] = 0
    $stats["from-1-Month-to-2-Month"] = 0
    $stats["from-2-Month-to-3-Month"] = 0 
    $stats["from-3-Month-to-6-Month"] = 0 
    $stats["from-6-Month-to-1-Year"] = 0
    $stats["from-1-Year-to-2-Year"] = 0
    $stats["greater-2-Year"] = 0
    $sendPerTeamStats = $adDomainNames.Length -gt 0
    $perTeamStats = @{}

    if ($sendPerTeamStats) {

        $perTeamStats['UnknownTeam'] = @{}
        $perTeamStats['UnknownTeam']["last-1-Month"] = 0
        $perTeamStats['UnknownTeam']["from-1-Month-to-2-Month"] = 0
        $perTeamStats['UnknownTeam']["from-2-Month-to-3-Month"] = 0 
        $perTeamStats['UnknownTeam']["from-3-Month-to-6-Month"] = 0 
        $perTeamStats['UnknownTeam']["from-6-Month-to-1-Year"] = 0
        $perTeamStats['UnknownTeam']["from-1-Year-to-2-Year"] = 0
        $perTeamStats['UnknownTeam']["greater-2-Year"] = 0

        $allTeams = $adComputers.Values | ? {$_ -ne $null} | select -Unique  | %{
            $teamName = $_
            $perTeamStats[$teamName] = @{}
            $perTeamStats[$teamName]["last-1-Month"] = 0
            $perTeamStats[$teamName]["from-1-Month-to-2-Month"] = 0
            $perTeamStats[$teamName]["from-2-Month-to-3-Month"] = 0 
            $perTeamStats[$teamName]["from-3-Month-to-6-Month"] = 0 
            $perTeamStats[$teamName]["from-6-Month-to-1-Year"] = 0
            $perTeamStats[$teamName]["from-1-Year-to-2-Year"] = 0
            $perTeamStats[$teamName]["greater-2-Year"] = 0
        }
    }
    $result | % {
        $oneComp = $_
        #Write-Warning "Process $oneComp"
        $teamName = "UnknownTeam"
        if (($adComputers.ContainsKey($oneComp.computerName)) -and ($adComputers[$oneComp.computerName] -ne $null))
        {
            $teamName = $adComputers[$oneComp.computerName]
        }
        
        ## select appropriate bucket
        switch ($true) {
         
            ($oneComp.latestInstalledUpdate -gt $lastMonth) {
                #"1-month " + $oneComp.latestInstalledUpdate + " - " + $oneComp.computerName 
                $stats["last-1-Month"]+=1
                if ($sendPerTeamStats) { $perTeamStats[$teamName]["last-1-Month"]+=1 }
                break
            }
            ($oneComp.latestInstalledUpdate -gt $lastTwoMonth) {
                #"2-month " + $oneComp.latestInstalledUpdate + " - " + $oneComp.computerName 
                $stats["from-1-Month-to-2-Month"]+=1
                if ($sendPerTeamStats) { $perTeamStats[$teamName]["from-1-Month-to-2-Month"]+=1 }
                break
            }
            ($oneComp.latestInstalledUpdate -gt $lastThreeMonth) {
                #"6-month " + $oneComp.latestInstalledUpdate + " - " + $oneComp.computerName 
                $stats["from-2-Month-to-3-Month"]+=1
                if ($sendPerTeamStats) { $perTeamStats[$teamName]["from-2-Month-to-3-Month"]+=1 }
                break
            }
            ($oneComp.latestInstalledUpdate -gt $lastSixMonth) {
                #"1-week " + $oneComp.latestInstalledUpdate + " - " + $oneComp.computerName 
                $stats["from-3-Month-to-6-Month"]+=1
                if ($sendPerTeamStats) { $perTeamStats[$teamName]["from-3-Month-to-6-Month"]+=1 }
                break
            }
            ($oneComp.latestInstalledUpdate -gt $lastOneYear) {
                #"1-year " + $oneComp.latestInstalledUpdate + " - " + $oneComp.computerName 
                $stats["from-6-Month-to-1-Year"]+=1
                if ($sendPerTeamStats) { $perTeamStats[$teamName]["from-6-Month-to-1-Year"]+=1 }
                break
            }
            ($oneComp.latestInstalledUpdate -gt $lastTwoYear) {
                #"1-year " + $oneComp.latestInstalledUpdate + " - " + $oneComp.computerName 
                $stats["from-1-Year-to-2-Year"]+=1
                if ($sendPerTeamStats) { $perTeamStats[$teamName]["from-1-Year-to-2-Year"]+=1 }
                break
            }
            default {
                #"older 2-year " + $oneComp.latestInstalledUpdate + " - " + $oneComp.computerName 
                $stats["greater-2-Year"]+=1
                if ($sendPerTeamStats) { $perTeamStats[$teamName]["greater-2-Year"]+=1 }
            }
        }

    }

    ## format output as Graphite Powershel Plugin specification required
    #$env = ($env:USERDNSDOMAIN -split "\.")[0]
    $stats.GetEnumerator() | % {
        $statName = $_.Name
        [pscustomobject]@{ Path="Aggregated.$statName"; Value=$_.Value}
    }

    $perTeamStats.GetEnumerator() | % {
        $teamName = $_.Name
            $_.Value.GetEnumerator() | % {
            $statName = $_.Name
            [pscustomobject]@{ Path="PerTeam.$teamName.$statName"; Value=$_.Value}
        }
    }
}

## skeleton
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

return [pscustomobject]@{PluginName = "WsusUpdatesStats"; FunctionName="GetWsusUpdateStats"; GlobalConfig=$GlobalConfig; ModuleConfig=$ModuleConfig; NodeHostName=$NodeHostName; MetricPath=$MetricPath }
