Param
(
    [Parameter(Mandatory=$false, Position=0,
        HelpMessage="File path to the input CSV that contains Logic App details to loop over and build a report from.")]
    [string]$InputCsv = "./inputs/Logic Apps List.csv",
    [Parameter(Mandatory=$false, Position=1,
        HelpMessage="File path to the directory of where to output the generated CSV files.")]
    [string]$OutputDir = "$($env:UserProfile)/Desktop",
    [Parameter(Mandatory=$false, Position=3,
        HelpMessage="Skip Azure authentication?")]
    [switch]$SkipAzAuth
)

Function Get-FilteredRunHistory([DateTime]$startTimeThreshold, [string]$inputCsv)
{
    $allFilteredRunHistory = New-Object System.Collections.ArrayList
    $subscriptionIndex = 0

    # Ignore records that have a Subscription ID that begins with a hash symbol.
    $logicAppList = Import-Csv $inputCsv | Where-Object { $_.SubscriptionId -notlike "#*" }
    $groupedLogicAppList = $logicAppList | Group-Object "SubscriptionId"

    foreach ($logicAppGroup in $groupedLogicAppList)
    {
        $subscriptionIndex += 1

        Write-Host("Changing Azure Subscription Context... (Subscription $($subscriptionIndex) of $($groupedLogicAppList.length) [ID: $($logicAppGroup.Name)])")
        Set-AzContext -SubscriptionId $logicAppGroup.Name | Out-Null
        Write-Host("Auzre Subscription Context Successfully Changed!")

        foreach ($logicApp in $logicAppGroup.Group)
        {
            $logicAppIndex += 1

            Write-Host("Getting Logic App Details and Run History... (Logic App $($logicAppIndex) of $($logicAppList.Count) [Name: $($logicApp.LogicAppName)])")

            $logicAppDetails = Get-AzLogicApp -ResourceGroupName $logicApp.ResourceGroupName `
                -Name $logicApp.LogicAppName

            $filteredRunHistory = Get-AzLogicAppRunHistory -ResourceGroupName $logicApp.ResourceGroupName `
                -Name $logicApp.LogicAppName |
                    Where-Object { [DateTime]$_.StartTime -ge $startTimeThreshold -and [DateTime]$_.StartTime -le $startTimeThreshold.AddDays(1) }

            Write-Host("Logic App Details and Run History Received!")

            if ($filteredRunHistory)
            {
                foreach ($runHistory in $filteredRunHistory)
                {
                    $allFilteredRunHistory.Add(@{
                        CustomerName = $logicApp.CustomerName
                        Direction = $logicApp.Direction
                        LogicAppName = $logicApp.LogicAppName
                        State = $logicAppDetails.State
                        RunId = $runHistory.Name
                        StartTime = $runHistory.StartTime
                        EndTime = $runHistory.EndTime
                        Status = $runHistory.Status
                    }) | Out-Null
                }
            }
            else
            {
                $allFilteredRunHistory.Add(@{
                    CustomerName = $logicApp.CustomerName
                    Direction = $logicApp.Direction
                    LogicAppName = $logicApp.LogicAppName
                    State = $logicAppDetails.State
                    RunId = "N/A"
                    StartTime = "N/A"
                    EndTime = "N/A"
                    Status = "No Executions"
                }) | Out-Null
            }
        }
    }

    return $allFilteredRunHistory
}

Function Get-ReportData([Object[]]$runHistory)
{
    $reportData = New-Object System.Collections.ArrayList

    $filteredRunHistory | Group-Object { $_.CustomerName } | ForEach-Object `
    {
        $customerReport = @{
            CustomerName = $_.Name
        }

        $_.Group | Group-Object { $_.Direction } | ForEach-Object `
        {
            $direction = $_.Name
            $earliestExecution = $_.Group | Sort-Object { $_.StartTime } | Select-Object -First 1
            $earliestStartTime = $earliestExecution.StartTime
            $logicAppState = $earliestExecution.State
            $succeededCount = 0
            $failedCount = 0
            $startedReport = ""
            $succeededReport = ""

            $_.Group | Group-Object { $_.Status } | ForEach-Object `
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

            if ($direction -eq "Inbound")
            {
                $customerReport.Add("EarliestInboundStartTime", $earliestStartTime)
                $customerReport.Add("InboundStarted", $startedReport)
                $customerReport.Add("InboundSucceeded", $succeededReport)
            }
            else
            {
                $customerReport.Add("EarliestOutboundStartTime", $earliestStartTime)
                $customerReport.Add("OutboundStarted", $startedReport)
                $customerReport.Add("OutboundSucceeded", $succeededReport)
            }
        }

        $reportData.Add($customerReport)
    }

    return $reportData
}


# # # # # # # # # # # # # #
#                         #
#  SCRIPT'S ENTRY POINT   #
#                         #
# # # # # # # # # # # # # #


if (-Not $SkipAzAuth.IsPresent)
{
    Connect-AzAccount
}

# Filter Logic App executions to only show runs that occurred after 12:00pm
# (Local Time) today.
$startTimeThreshold = (Get-Date).Date.AddHours(12)

# If running before 6:00pm (Local Time) show yesterday's executions.
if ((Get-Date) -lt (Get-Date).Date.AddHours(18))
{
    $startTimeThreshold = $startTimeThreshold.AddDays(-1)
}

$filteredRunHistory = Get-FilteredRunHistory -startTimeThreshold $startTimeThreshold -inputCsv $InputCsv
$reportData = Get-ReportData($filteredRunHistory) | Sort-Object { $_.EarliestInboundStartTime }

# Output Raw CSV.
$outputCsv = New-Object IO.StreamWriter("$($OutputDir)/Logic Apps Run History (Raw).csv")
$outputCsv.WriteLine("CustomerName,Direction,LogicAppName,State,RunId,StartTime,EndTime,RunStatus")
foreach ($runHistory in $filteredRunHistory)
{
    $outputCsv.WriteLine("$($runHistory.CustomerName),$($runHistory.Direction),$($runHistory.LogicAppName),$($runHistory.State),$($runHistory.RunId),$($runHistory.StartTime),$($runHistory.EndTime),$($runHistory.Status)")
}
$outputCsv.Close()

# Output Report CSV.
$outputCsv = New-Object IO.StreamWriter("$($OutputDir)/Logic Apps Run History (Report).csv")
$outputCsv.WriteLine("CustomerName,InboundStartTime,InboundStarted,InboundSucceeded,OutboundStartTime,OutboundStarted,OutboundSucceeded")
foreach($customer in $reportData)
{
    if ($customer.GetType().Name -eq "Hashtable")
    {
        $outputCsv.WriteLine("$($customer.CustomerName),$($customer.EarliestInboundStartTime),$($customer.InboundStarted),$($customer.InboundSucceeded),$($customer.EarliestOutboundStartTime),$($customer.OutboundStarted),$($customer.OutboundSucceeded)")
    }
}
$outputCsv.Close()

Write-Host("")
