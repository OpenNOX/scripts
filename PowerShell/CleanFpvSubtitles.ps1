Param
(
    [Parameter()]
    [string] $RootDir = "D:\FPV Videos"
)

Get-ChildItem $RootDir -Filter *.srt -Recurse | ForEach-Object { `
    $tempPath = "$($_.FullName).temp"

    (Get-Content -Path $_.FullName) `
        -replace 'signal:\d* ch:\d* (flightTime:\d*) (uavBat:\d*\.\d*V) glsBat:\d*% uavBatCells:\d* glsBatCells:\d* (delay:\d*ms) (bitrate:\d*\.\d*Mbps) rcSignal:\d*', '$1s $2 $3 $4' `
    | Add-Content -Path $tempPath

    Remove-Item -Path $_.FullName
    Move-Item -Path $tempPath -Destination $_.FullName
}
