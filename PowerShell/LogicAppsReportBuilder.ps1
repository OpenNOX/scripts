Param
(
    $inputCsvPath = "./inputs/Logic Apps List.csv",
    $outputCsvPath = "$($env:UserProfile)/Desktop/Logic Apps Report.csv"
)

# Connect-AzAccount

# Filter Logic App executions to only show runs that occurred after 12:00pm
# (Local Time) today.
$startTimeThreshold = (Get-Date).Date.AddHours(12)

# If running before 6:00pm (Local Time) show yesterday's runs.
if ((Get-Date) -lt (Get-Date).Date.AddHours(18))
{
    $startTimeThreshold = $startTimeThreshold.AddDays(-1)
}

# Ignore records that have Subscription IDs that begin with a hash tag.
$groupedLogicAppList = Import-Csv $inputCsvPath |
    Where-Object { $_.SubscriptionId -notlike "#*" } |
    Group-Object "SubscriptionId"

$subscriptionIndex = 0
$allRunHistory = New-Object System.Collections.ArrayList

foreach ($logicAppGroup in $groupedLogicAppList)
{
    $subscriptionIndex += 1
    $logicAppIndex = 0

    Write-Host("Changing Azure Context (Subscription: $($logicAppGroup.Name))...")
    Set-AzContext -SubscriptionId $logicAppGroup.Name | Out-Null
    Write-Host("Auzre Context Successfully Changed! (Subscription $($subscriptionIndex) of $($groupedLogicAppList.length))")

    foreach ($logicApp in $logicAppGroup.Group)
    {
        $logicAppIndex += 1

        Write-Host("Getting Logic App Details and Run History (Logic App: $($logicApp.LogicAppName))...")

        $logicAppDetails = Get-AzLogicApp -ResourceGroupName $logicApp.ResourceGroupName `
            -Name $logicApp.LogicAppName

        $filteredRunHistory = Get-AzLogicAppRunHistory -ResourceGroupName $logicApp.ResourceGroupName `
            -Name $logicApp.LogicAppName |
                Where-Object { [DateTime]$_.StartTime -ge $startTimeThreshold -and [DateTime]$_.StartTime -le $startTimeThreshold.AddDays(1) }

        Write-Host("Logic App Details and Run History Received! (Logic App $($logicAppIndex) of $($logicAppGroup.Count) in Subscription)")

        if ($filteredRunHistory)
        {
            foreach ($runHistory in $filteredRunHistory)
            {
                $allRunHistory.Add(@{
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
            $allRunHistory.Add(@{
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

# Write output CSV headers.
$outputCsv = New-Object IO.StreamWriter($outputCsvPath)
$outputCsv.WriteLine("CustomerName,Direction,LogicAppName,State,RunId,StartTime,EndTime,RunStatus")

foreach ($runHistory in $allRunHistory)
{
    $outputCsv.WriteLine("$($runHistory.CustomerName),$($runHistory.Direction),$($runHistory.LogicAppName),$($runHistory.State),$($runHistory.RunId),$($runHistory.StartTime),$($runHistory.EndTime),$($runHistory.Status)")
}

# Close output CSV.
$outputCsv.Close()
