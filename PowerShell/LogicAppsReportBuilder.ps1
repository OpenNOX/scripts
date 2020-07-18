Param
(
    [Parameter()]
    [string] $InputCsvPath = "$((Get-Location).Path)\inputs\Logic Apps List.csv",
    [Parameter()]
    [string] $OutputDir = "$((Get-Location).Path)\outputs",
    [Parameter()]
    [int32] $ThresholdOffset = 0,
    [Parameter()]
    [switch] $SkipAzAuth,
    [Parameter()]
    [switch] $SkipAzData
)


#
# Get Timestamp - Returns formatted timestamp.
#
Function Get-Timestamp
{
    return "[{0:yy.MM.dd} {0:HH:mm:ss}]" -f (Get-Date)
}


#
# Get Failed Actions Output - Recursively retrieve failed action outputs.
#
Function Write-FailedActionOutputs([string] $FailedCsvPath, [string] $CustomerName, [string] $ResourceGroupName, [string] $LogicAppName, [string] $RunId)
{
    Get-AzLogicAppRunAction -ResourceGroupName $ResourceGroupName -Name $LogicAppName -RunName $RunId `
        | Where-Object { $_.Status -eq "Failed" } | ForEach-Object `
        {
            $inputs = (Invoke-WebRequest -Uri $_.InputsLink.Uri).Content | ConvertFrom-Json
            $outputs = (Invoke-WebRequest -Uri $_.OutputsLink.Uri).Content | ConvertFrom-Json

            if ($inputs.psobject.Properties["host"] -and $inputs.host.psobject.Properties["triggerName"] -and $inputs.host.triggerName -eq "manual")
            {
                $logicAppName = $outputs.headers.psobject.Members["x-ms-workflow-name"].Value
                $runId = $outputs.headers.psobject.Members["x-ms-workflow-run-id"].Value

                Write-Host("$(Get-Timestamp) Retrieving failed nested Logic App (Name: $($logicAppName)) runs failed action outputs for $($runId)...")
                Write-FailedActionOutputs -FailedCsvPath $FailedCsvPath `
                    -CustomerName $CustomerName `
                    -ResourceGroupName $ResourceGroupName `
                    -LogicAppName  $logicAppName `
                    -RunId $runId
            }
            else
            {
                Add-Content -Path $FailedCsvPath `
                    -Value "$($CustomerName),$($LogicAppName),$($RunId),""$($outputs.body.message)"",""$($outputs.body.stack)"",$($_.OutputsLink.Uri)"
            }
        }
}


#
# Write Azure Data to CSV - Write filtered Logic App run history to DataCsvPath.
#
Function Write-AzureDataToCsv([Object[]] $LogicAppList, [string] $DataCsvPath, [string] $FailedCsvPath, [int32] $ThresholdOffset)
{
    New-Item -ItemType File -Path $DataCsvPath -Force | Out-Null
    Add-Content -Path $DataCsvPath -Value "CustomerName,Direction,LogicAppName,State,RunId,StartTime,EndTime,RunStatus"
    New-Item -ItemType File -Path $FailedCsvPath -Force | Out-Null
    Add-Content -Path $FailedCsvPath -Value "CustomerName,LogicAppName,RunId,Message,Stack,OutputUrl"

    $groupedLogicAppList = $LogicAppList | Group-Object { $_.SubscriptionId }

    # Filter Logic App run history to only show executions that occurred between
    # 12:00pm today and 12:00pm (Local Time) tomorrow.
    $logicAppStartTimeThreshold = (Get-Date).Date.AddDays(-$ThresholdOffset).AddHours(12)

    # If running before 6:00pm (Local Time) and ThresholdOffset is equal to 0
    # show yesterday's run history.
    if ((Get-Date) -lt (Get-Date).Date.AddHours(18) -and $ThresholdOffset -eq 0)
    {
        $logicAppStartTimeThreshold = $logicAppStartTimeThreshold.AddDays(-1)
    }

    Write-Host("$(Get-Timestamp) Retrieving run history for $($LogicAppList.Count) Logic Apps in $($groupedLogicAppList.Count) Subscriptions...")
    Write-Host("$(Get-Timestamp) Logic App run history will be filtered by StartTime that ranges between $($logicAppStartTimeThreshold) and $($logicAppStartTimeThreshold.AddDays(1))")

    $currentSubscriptionIndex = 0
    $currentLogicAppIndex = 0
    foreach ($subscriptionGroup in $groupedLogicAppList)
    {
        $currentSubscriptionIndex += 1

        Write-Host("$(Get-Timestamp) Updating Azure Subscription context to be $($subscriptionGroup.Name)... ($($currentSubscriptionIndex) of $($groupedLogicAppList.Count))")
        Set-AzContext -SubscriptionId $subscriptionGroup.Name | Out-Null
        Write-Host("$(Get-Timestamp) Azure Subscription context successfully updated!")

        foreach ($logicApp in $subscriptionGroup.Group)
        {
            $currentLogicAppIndex += 1

            Write-Host("$(Get-Timestamp) Retrieving Logic App details and run history for $($logicApp.LogicAppName)... ($($currentLogicAppIndex) of $($LogicAppList.Count))")

            $logicAppDetails = Get-AzLogicApp -ResourceGroupName $logicApp.ResourceGroupName `
                -Name $logicApp.LogicAppName
            $filteredRunHistory = Get-AzLogicAppRunHistory -ResourceGroupName $logicApp.ResourceGroupName `
                -Name $logicApp.LogicAppName `
                | Where-Object `
                { `
                    [DateTime] $_.StartTime -ge $logicAppStartTimeThreshold `
                    -and `
                    [DateTime] $_.StartTime -le $logicAppStartTimeThreshold.AddDays(1) `
                }

            Write-Host("$(Get-Timestamp) Successfully retrieved Logic App details and run history!")

            if ($filteredRunHistory)
            {
                $currentFailedRunIndex = 0
                $failedRunCount = ($filteredRunHistory | Where-Object { $_.Status -eq "Failed" }).Count

                foreach ($runHistory in $filteredRunHistory)
                {
                    if ($runHistory.Status -eq "Failed")
                    {
                        $currentFailedRunIndex += 1

                        Write-Host("$(Get-Timestamp) Retrieving failed Logic App runs failed action outputs for $($runHistory.Name)... ($($currentFailedRunIndex) of $($failedRunCount))")
                        Write-FailedActionOutputs -FailedCsvPath $FailedCsvPath `
                            -CustomerName $logicApp.CustomerName `
                            -ResourceGroupName $logicApp.ResourceGroupName `
                            -LogicAppName $logicApp.LogicAppName `
                            -RunId $runHistory.Name
                        Write-Host("$(Get-Timestamp) Logic App runs failed action outputs successfully retrieved!")
                    }

                    Add-Content -Path $DataCsvPath `
                        -Value "$($logicApp.CustomerName),$($logicApp.Direction),$($logicApp.LogicAppName),$($logicAppDetails.State),$($runHistory.Name),$($runHistory.StartTime),$($runHistory.EndTime),$($runHistory.Status)"
                }
            }
            else
            {
                Add-Content -Path $DataCsvPath `
                    -Value "$($logicApp.CustomerName),$($logicApp.Direction),$($logicApp.LogicAppName),$($logicAppDetails.State),N/A,N/A,N/A,N/A"
            }
        }
    }

    Write-Host("$(Get-Timestamp) All run history successfully retrieved!")
}


#
# Write Report to CSV - Write report on Logic App run history.
#
Function Write-Report([string] $DataCsvPath, [string] $ReportCsvPath, [string[]] $SortOrder)
{
    New-Item -ItemType File -Path $ReportCsvPath -Force | Out-Null
    Add-Content -Path $ReportCsvPath -Value "CustomerName,InboundStartTime,InboundStarted,InboundSucceeded,OutboundStartTime,OutboundStarted,OutboundSucceeded"

    Import-Csv $DataCsvPath | Group-Object { $_.CustomerName } | Sort-Object { $SortOrder.IndexOf($_.Name) } | ForEach-Object `
    {
        $reportLine = @{
            CustomerName = $_.Name
        }

        $_.Group | Group-Object { $_.Direction } | ForEach-Object `
        {
            $earliestExecution = $_.Group | Sort-Object { $_.StartTime } | Select-Object -First 1
            $earliestStartTime = $earliestExecution.StartTime
            $logicAppState = $earliestExecution.State
            $succeededCount = 0
            $failedCount = 0
            $startedReport = ""
            $succeededReport = ""

            $_.Group | Group-Object { $_.RunStatus } | ForEach-Object `
            {
                if ($_.Name -eq "Succeeded")
                {
                    Set-Variable -Name "succeededCount" -Value $_.Count
                }
                elseif ($_.Name -eq "Failed")
                {
                    Set-Variable -Name "failedCount" -Value $_.Count
                }
            }

            if ($failedCount -ge 1 -and $succeededCount -eq 0)
            {
                $startedReport = "Y"
                $succeededReport = "N"
            }
            elseif ($failedCount -ge 1 -and $succeededCount -ge 1)
            {
                $startedReport = "Y"
                $succeededReport = "Y$($failedCount)"
            }
            elseif ($failedCount -eq 0 -and $succeededCount -ge 1)
            {
                $startedReport = "Y"
                $succeededReport = "Y"
            }
            elseif ($logicAppState -eq "Disabled")
            {
                $startedReport = "P"
                $succeededReport = "P"
            }

            if ($_.Name -eq "Inbound")
            {
                $reportLine.Add("EarliestInboundStartTime", $earliestStartTime)
                $reportLine.Add("InboundStarted", $startedReport)
                $reportLine.Add("InboundSucceeded", $succeededReport)
            }
            elseif ($_.Name -eq "Outbound")
            {
                $reportLine.Add("EarliestOutboundStartTime", $earliestStartTime)
                $reportLine.Add("OutboundStarted", $startedReport)
                $reportLine.Add("OutboundSucceeded", $succeededReport)
            }
        }

        Add-Content -Path $ReportCsvPath `
            -Value "$($reportLine.CustomerName),$($reportLine.EarliestInboundStartTime),$($reportLine.InboundStarted),$($reportLine.InboundSucceeded),$($reportLine.EarliestOutboundStartTime),$($reportLine.OutboundStarted),$($reportLine.OutboundSucceeded)"
    }
}


# # # # # # # # # # # # # #
#                         #
#   Script Entry Point    #
#                         #
# # # # # # # # # # # # # #


Write-Host("$(Get-Timestamp) Now running Logic Apps Report Builder...")
Write-Host("$(Get-Timestamp) Input CSV File Path -> $($InputCsvPath)")
Write-Host("$(Get-Timestamp) Output Directory -> $($OutputDir)")

$dataCsvPath = "$($OutputDir)\Logic Apps Run History (Data).csv"
$failedCsvPath = "$($OutputDir)\Logic Apps Run History (Failed).csv"
$reportCsvPath = "$($OutputDir)\Logic Apps Run History (Report).csv"

# Ignore records that have a Subscription ID that begins with a hash symbol.
$logicAppList = Import-Csv $InputCsvPath | Where-Object { $_.SubscriptionId -notlike "#*" }

if (-Not $SkipAzData.IsPresent)
{
    if (-Not $SkipAzAuth.IsPresent)
    {
        Write-Host("$(Get-Timestamp) Waiting for Azure authentication...")
        Connect-AzAccount | Out-Null
    }

    Write-AzureDataToCsv -LogicAppList $logicAppList `
        -DataCsvPath $dataCsvPath `
        -FailedCsvPath $failedCsvPath `
        -ThresholdOffset $ThresholdOffset
}

# Sort report output order by the Logic App List order.
Write-Report -DataCsvPath $dataCsvPath `
    -ReportCsvPath $reportCsvPath `
    -SortOrder ($logicAppList | Group-Object { $_.CustomerName } | Select-Object -ExpandProperty Name)

Write-Host("$(Get-Timestamp) Logic Apps Report Build has been successfully run!")
Write-Host("")
