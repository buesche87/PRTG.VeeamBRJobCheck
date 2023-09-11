<#
    .SYNOPSIS
    This script checks the status of all active Veeam Backup & Replication jobs on a backup server.
    It collects detailed information and creates an XML file per backupjob as output.

    .INPUTS
    None

    .OUTPUTS
    The script creates a XML file formated for PRTG.

    .LINK
    https://raw.githubusercontent.com/tn-ict/Public/master/Disclaimer/DISCLAIMER

    .NOTES
    Author  : Andreas Bucher
    Version : 0.9.4
    Purpose : XML part of the PRTG-Sensor VeeamBRJobCheck

    .EXAMPLE
    Run this script with task scheduler use powershell.exe as program and the following parameters:
    -NoProfile -NoLogo -NonInteractive -ExecutionPolicy Bypass -File "C:\Script\VeeamBRJobCheck-XML.ps1"
    This will place a file in C:\Temp\VeeamResults where it can be retreived by the PRTG sensor
#>
#----------------------------------------------------------[Declarations]----------------------------------------------------------
# Include
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
if (Get-Module -ListAvailable -Name Veeam.Backup.PowerShell) {
    # Include PS-Module from Veeam Backup & Replication V11 and above
    Import-Module Veeam.Backup.PowerShell
}
elseif (Get-PSSnapin -Registered -Name VeeamPSSnapIn) {
    # Include PS-Snapin from Veeam Backup & Replication V10
    Add-PSSnapin -Name VeeamPSSnapIn
}
else {
    exit 1
}

# General parameters
$UpdatePath       = "https://raw.githubusercontent.com/buesche87/PRTG.VeeamBRJobCheck/main/VeeamBRJobCheck-XML.ps1"
$nl               = [Environment]::NewLine
$resultFolder     = "C:\Temp\VeeamResults"

# PRTG parameters
$WarningLevel = 24 # Warninglevel in hours for last backup session
$ErrorLevel   = 36 # Errorlevel in hours for last backup session

# Define JobResult object and parameters
$JobResult = [PSCustomObject]@{
    Name     = ""
    Value    = 0
    Text     = ""
    Warning  = 0
    Error    = 0
    Countobj = 0
    duration = 0
    avgspeed = 0
    Lastbkp  = 0
    progress = 0
    percent  = 0
    psize    = 0
    pcu      = ""
    tsize    = 0
    tcu      = ""
    rsize    = 0
    rcu      = ""
    usize    = 0
    ucu      = ""
}

#-----------------------------------------------------------[Functions]------------------------------------------------------------
# Export XML
function Set-XMLContent {
    param(
        $JobResult
    )

    # Create XML-Content
    $result= ""
    $result+= '<?xml version="1.0" encoding="UTF-8" ?>' + $nl
    $result+= "<prtg>" + $nl

    $result+=   "<Error>$($JobResult.Error)</Error>" + $nl
    $result+=   "<Text>$($JobResult.Text)</Text>" + $nl

    $result+=   "<result>" + $nl
    $result+=   "  <channel>Status</channel>" + $nl
    $result+=   "  <value>$($JobResult.Value)</value>" + $nl
    $result+=   "  <Warning>$($JobResult.Warning)</Warning>" + $nl
    $result+=   "  <LimitMaxWarning>2</LimitMaxWarning>" + $nl
    $result+=   "  <LimitMaxError>3</LimitMaxError>" + $nl
    $result+=   "  <LimitMode>1</LimitMode>" + $nl
    $result+=   "  <showChart>1</showChart>" + $nl
    $result+=   "  <showTable>1</showTable>" + $nl
    $result+=   "</result>" + $nl

    $result+=   "<result>" + $nl
    $result+=   "  <channel>Abgearbeitete Objekte</channel>" + $nl
    $result+=   "  <value>$($JobResult.countobj)</value>" + $nl
    $result+=   "  <showChart>1</showChart>" + $nl
    $result+=   "  <showTable>1</showTable>" + $nl
    $result+=   "</result>" + $nl

    $result+=   "<result>" + $nl
    $result+=   "  <channel>Abgearbeitet</channel>" + $nl
    $result+=   "  <value>$($JobResult.psize)</value>" + $nl
    $result+=   "  <Float>1</Float>" + $nl
    $result+=   "  <CustomUnit>$($JobResult.pcu)</CustomUnit>" + $nl
    $result+=   "  <showChart>1</showChart>" + $nl
    $result+=   "  <showTable>1</showTable>" + $nl
    $result+=   "</result>" + $nl

    $result+=   "<result>" + $nl
    $result+=   "  <channel>Gelesen</channel>" + $nl
    $result+=   "  <value>$($JobResult.rsize)</value>" + $nl
    $result+=   "  <Float>1</Float>" + $nl
    $result+=   "  <CustomUnit>$($JobResult.rcu)</CustomUnit>" + $nl
    $result+=   "  <showChart>1</showChart>" + $nl
    $result+=   "  <showTable>1</showTable>" + $nl
    $result+=   "</result>" + $nl

    $result+=   "<result>" + $nl
    $result+=   "  <channel>Transferiert</channel>" + $nl
    $result+=   "  <value>$($JobResult.tsize)</value>" + $nl
    $result+=   "  <Float>1</Float>" + $nl
    $result+=   "  <CustomUnit>$($JobResult.tcu)</CustomUnit>" + $nl
    $result+=   "  <showChart>1</showChart>" + $nl
    $result+=   "  <showTable>1</showTable>" + $nl
    $result+=   "</result>" + $nl

    $result+=   "<result>" + $nl
    $result+=   "  <channel>Belegt</channel>" + $nl
    $result+=   "  <value>$($JobResult.usize)</value>" + $nl
    $result+=   "  <Float>1</Float>" + $nl
    $result+=   "  <CustomUnit>$($JobResult.ucu)</CustomUnit>" + $nl
    $result+=   "  <showChart>1</showChart>" + $nl
    $result+=   "  <showTable>1</showTable>" + $nl
    $result+=   "</result>" + $nl

    $result+=   "<result>" + $nl
    $result+=   "  <channel>Dauer</channel>" + $nl
    $result+=   "  <value>$($JobResult.Duration)</value>" + $nl
    $result+=   "  <Float>1</Float>" + $nl
    $result+=   "  <CustomUnit>Min</CustomUnit>" + $nl
    $result+=   "  <showChart>1</showChart>" + $nl
    $result+=   "  <showTable>1</showTable>" + $nl
    $result+=   "</result>" + $nl

    $result+=   "<result>" + $nl
    $result+=   "  <channel>Durchsatz</channel>" + $nl
    $result+=   "  <value>$($JobResult.avgspeed)</value>" + $nl
    $result+=   "  <Float>1</Float>" + $nl
    $result+=   "  <CustomUnit>MB/s</CustomUnit>" + $nl
    $result+=   "  <showChart>1</showChart>" + $nl
    $result+=   "  <showTable>1</showTable>" + $nl
    $result+=   "</result>" + $nl

    $result+=   "<result>" + $nl
    $result+=   "  <channel>Stunden seit letzem Job</channel>" + $nl
    $result+=   "  <value>$($JobResult.Lastbkp)</value>" + $nl
    $result+=   "  <CustomUnit>h</CustomUnit>" + $nl
    $result+=   "  <showChart>1</showChart>" + $nl
    $result+=   "  <showTable>1</showTable>" + $nl
    $result+=   "  <LimitMaxWarning>$WarningLevel</LimitMaxWarning>" + $nl
    $result+=   "  <LimitWarningMsg>Backup-Job &#228;lter als 24h</LimitWarningMsg>" + $nl
    $result+=   "  <LimitMaxError>$ErrorLevel</LimitMaxError>" + $nl
    $result+=   "  <LimitErrorMsg>Backup-Job &#228;lter als 36h</LimitErrorMsg>" + $nl
    $result+=   "  <LimitMode>1</LimitMode>" + $nl
    $result+=   "</result>" + $nl

    $result+= "</prtg>" + $nl

    # Write XML-File
    if(-not (test-path $resultFolder)){ New-Item -Path $resultFolder -ItemType Directory }
    $xmlFilePath = "$resultFolder\$($JobResult.Name).xml"
    $result | Out-File $xmlFilePath -Encoding utf8

}
# Calculate backupjob result details
function Get-TaskResult {
    param(
        $Tasks
    )

    # Reset Values
    [int]$countobj   = 0
    [float]$rsize    = 0
    [float]$tsize    = 0
    [float]$psize    = 0
    [float]$usize    = 0
    [float]$duration = 0
    [float]$avgspeed = 0
    [float]$percent  = 0

    # Get details from each task
    foreach ($task in $Tasks) {
        $countobj += $task.Progress.ProcessedObjects
        $rsize    += $task.Info.Progress.ReadSize
        $tsize    += $task.Info.Progress.TransferedSize
        $psize    += $task.Info.Progress.ProcessedSize
        $usize    += $task.Info.Progress.TotalUsedSize
        $duration = [Math]::Round([Decimal]$task.Info.Progress.Duration.TotalMinutes ,0)
        if ( -not ($task.Info.Progress.AvgSpeed -eq 0)) { $avgspeed = [Math]::Round([Decimal]$task.Info.Progress.AvgSpeed/1MB, 1) }
        if ($task.Progress.Percents -lt 100) {$percent += $task.Progress.Percents}
    }

    # Fill JobResult
    $JobResult.countobj = $countobj
    $JobResult.duration = $duration
    $JobResult.avgspeed = $avgspeed
    $JobResult.percent  = $percent

    # Set channel custom units
    $JobResult = Set-CustomUnit $JobResult $rsize $tsize $psize $usize

    Return $JobResult
}

# Check backupjob status
function Get-SessionState {
    param(
        $Session,
        $JobResult
    )

    # Check if Session has a percentage state
    if ($Session.Progress -is [int] -and $JobResult.Percent -eq 0) { $JobResult.Percent = $Session.Progress }

    # Get job results and define result parameters
    if     ($Session.Result -eq "Success")        { $JobResult.Value = 1; $JobResult.Warning = 0; $JobResult.Error = 0; $JobResult.Text = "BackupJob $($JobResult.Name) erfolgreich" }
    elseif ($Session.Result -eq "Warning")        { $JobResult.Value = 2; $JobResult.Warning = 1; $JobResult.Error = 0; $JobResult.Text = "BackupJob $($JobResult.Name) Warnung. Bitte pr&#252;fen" }
    elseif ($Session.Result -eq "Failed")         { $JobResult.Value = 3; $JobResult.Warning = 0; $JobResult.Error = 1; $JobResult.Text = "BackupJob $($JobResult.Name) fehlerhaft" }
    elseif ($Session.State  -eq "Working")        { $JobResult.Value = 2; $JobResult.Warning = 1; $JobResult.Error = 0; $JobResult.Text = "BackupJob $($JobResult.Name) l&#228;uft noch: $($JobResult.Percent) %"  }
    elseif ($Session.State  -eq "Postprocessing") { $JobResult.Value = 2; $JobResult.Warning = 1; $JobResult.Error = 0; $JobResult.Text = "BackupJob $($JobResult.Name) Nachbearbeitung" }
    elseif ($Session.State  -eq "WaitingTape")    { $JobResult.Value = 2; $JobResult.Warning = 1; $JobResult.Error = 0; $JobResult.Text = "BackupJob $($JobResult.Name) wartet auf Tape" }
    else                                          { $JobResult.Value = 3; $JobResult.Warning = 0; $JobResult.Error = 1; $JobResult.Text = "BackupJob $($JobResult.Name) unbekannter Fehler" }

    Return $JobResult
}

# Check for Task Logs
function Get-TaskLog {
    param(
        $Tasks
    )

    # Get warning messages for each task
    $warningmsg = ""
    foreach ($Task in $Tasks) {
        $warningmsg += ($Task.logger.getlog().updatedrecords | Where-Object {$_.status -like "*Warning"} | Select-Object title).Title
    }

    # Get error messages for each task
    $failedmsg = ""
    foreach ($Task in $Tasks) {
        $failedmsg += ($Task.logger.getlog().updatedrecords | Where-Object {$_.status -like "*Failed"} | Select-Object title).Title
    }

    if ($failedmsg)      { Return $failedmsg }
    elseif ($warningmsg) { Return $warningmsg }
    else                 { Return }
}

# Check for Session Logs
function Get-SessionLog {
    param(
        $Session
    )

    # Get warning messages for each task
    $warningmsg = ""
    foreach ($Task in $Session) {
        $warningmsg += ($Task.Log | Where-Object {$_.status -like "*Warning"} | Select-Object title).Title
    }

    # Get error messages for each task
    $failedmsg = ""
    foreach ($Task in $Session) {
        $failedmsg += ($Task.Log | Where-Object {$_.status -like "*Failed"} | Select-Object title).Title
    }

    if ($failedmsg)      { Return $failedmsg }
    elseif ($warningmsg) { Return $warningmsg }
    else                 { Return }
}

# Caclulate custom units
function Set-CustomUnit {
    param(
        $JobResult,
        $rsize,
        $tsize,
        $psize,
        $usize
    )

    # Set readsize customunit
    $strlength = ($rsize).ToString().Length
    if ( $strlength -lt 7 ) {
        $JobResult.rcu   = "KB"
        $JobResult.rsize = [Math]::Round([Decimal]$rsize/1KB, 1)
    }
    elseif ($strlength -lt 10 ) {
        $JobResult.rcu   = "MB"
        $JobResult.rsize = [Math]::Round([Decimal]$rsize/1MB, 1)
    }
    else {
        $JobResult.rcu   = "GB"
        $JobResult.rsize = [Math]::Round([Decimal]$rsize/1GB, 1)
    }

    # Set transfersize customunit
    $strlength = ($tsize).ToString().Length
    if ( $strlength -lt 7 ) {
        $JobResult.tcu   = "KB"
        $JobResult.tsize = [Math]::Round([Decimal]$tsize/1KB, 1)
    }
    elseif ($strlength -lt 10 ) {
        $JobResult.tcu   = "MB"
        $JobResult.tsize = [Math]::Round([Decimal]$tsize/1MB, 1)
    }
    else {
        $JobResult.tcu   = "GB"
        $JobResult.tsize = [Math]::Round([Decimal]$tsize/1GB, 1)
    }

    # Set processedsize customunit
    $strlength = ($psize).ToString().Length
    if ( $strlength -lt 7 ) {
        $JobResult.pcu   = "KB"
        $JobResult.psize = [Math]::Round([Decimal]$psize/1KB, 1)
    }
    elseif ($strlength -lt 10 ) {
        $JobResult.pcu   = "MB"
        $JobResult.psize = [Math]::Round([Decimal]$psize/1MB, 1)
    }
    else {
        $JobResult.pcu   = "GB"
        $JobResult.psize = [Math]::Round([Decimal]$psize/1GB, 1)
    }

    # Set usedsize customunit
    $strlength = ($usize).ToString().Length
    if ( $strlength -lt 7 ) {
        $JobResult.ucu   = "KB"
        $JobResult.usize = [Math]::Round([Decimal]$usize/1KB, 1)
    }
    elseif ($strlength -lt 10 ) {
        $JobResult.ucu   = "MB"
        $JobResult.usize = [Math]::Round([Decimal]$usize/1MB, 1)
    }
    else {
        $JobResult.ucu   = "GB"
        $JobResult.usize = [Math]::Round([Decimal]$usize/1GB, 1)
    }

    Return $JobResult
}

# Update Script
function Get-NewScript {

    # Check if Update-Script is reachable
    $StatusCode = Invoke-WebRequest $UpdatePath -UseBasicParsing | ForEach-Object {$_.StatusCode}
    $CurrentScript = $PSCommandPath

    if ($StatusCode -eq 200 ) {

        # Parse version string of script on github
        $UpdateScriptcontent = (Invoke-webrequest -URI $UpdatePath -UseBasicParsing).Content
        $newversionstring    = ($UpdateScriptcontent | Select-String "Version :.*" | Select-Object -First 1).Matches.Value
        $newversion          = $newversionstring -replace '[^0-9"."]',''

        # Parse version string of current script
        $CurrentScriptContent = Get-Content -Path $PSCommandPath -Encoding UTF8 -Raw
        $currentversionstring = ($CurrentScriptContent | Select-String "Version :.*" | Select-Object -First 1).Matches.Value
        $currentversion       = $currentversionstring -replace '[^0-9"."]',''

        # Replace and re-run script if update-script is newer
        if ([version]$newversion -gt [version]$currentversion) {

            # Create temp directory if it does not exists
            $tmpdirectory = "C:\Temp"
            if(-not (test-path $tmpdirectory)){ New-Item -Path $tmpdirectory -ItemType Directory }

            # Create a temporary file with content of the new script
            $tempfile = "$tmpdirectory\update-script.new"
            Invoke-WebRequest -URI $UpdatePath -outfile $tempfile

            # Replace current script
            $content = Get-Content $tempfile -Encoding utf8 -raw
            $content | Set-Content $CurrentScript -encoding UTF8

            # Remove temporary file
            Remove-Item $tempfile

            # Call new script
            &$CurrentScript $script:args
        }
    }
}
#-----------------------------------------------------------[Execute]------------------------------------------------------------
# Autouptade Script
Get-NewScript

# Get VMWare Backups
$VMWareJobs = Get-VBRJob | where-object { $_.IsScheduleEnabled -and $_.JobType -eq "Backup" -and $_.SourceType -eq "VDDK" }

# Get Hyper-V BackupJobs
$HyperVJobs = Get-VBRJob | where-object { $_.IsScheduleEnabled -and $_.JobType -eq "Backup" -and $_.SourceType -eq "HyperV"}

# Get BackupCopyJobs
$BackupCopyJobs = Get-VBRJob | where-object { $_.IsScheduleEnabled -and $_.JobType -eq "BackupSync" }

# Get SimpleBackupCopyJobs
$SimpleBackupCopyJobs = Get-VBRJob | where-object { $_.IsScheduleEnabled -and $_.JobType -eq "SimpleBackupCopyPolicy" }

# Get TapeJobs
$Tapejobs = Get-VBRTapeJob | where-object { $_.Enabled }

# Get Linux Agent Jobs
$LinuxAgentJobs = Get-VBRBackup | where-object { $_.JobType -eq "EndpointBackup"}

# Get Windows Agent Jobs
$WinAgentJobs = Get-VBRComputerBackupJob | where-object { $_.JobEnabled }

# Get NAS Backup Jobs
$NASJobs = Get-VBRJob | where-object { $_.IsScheduleEnabled -and $_.JobType -eq "NasBackup" }

# Get NAS Backup Copy Jobs
$NASCopyJobs = Get-VBRJob | where-object { $_.IsScheduleEnabled -and $_.JobType -eq "NasBackupCopy" }

# Get File Copy Jobs
$FileCopyJobs = Get-VBRJob | where-object { $_.IsScheduleEnabled -and $_.JobType -eq "Copy" }

#### Get VMWare Bckup details ######################################################################################################
foreach($item in $VMWareJobs) {

    $JobResult.Name = $item.Name

    # Load details
    $Job     = Get-VBRJob -Name $item.name
    $Session = Get-VBRSession -Job $job -Last
    $Tasks   = Get-VBRTaskSession -Session $Session

    # Check Session results
    $JobResult = Get-TaskResult $Tasks
    $JobResult = Get-SessionState $Session $JobResult
    $JobResult.LastBkp = (New-TimeSpan -Start $Session.CreationTime -End (Get-Date)).Hours
    $CheckJobError = Get-TaskLog $Tasks
    $CheckJobError += Get-SessionLog $Session
    if ($CheckJobError) { $JobResult.Text = $CheckJobError }

    # Create XML
    Set-XMLContent -JobResult $JobResult -HoursSince $HoursSince
}

#### Get HyperVJobs Bckup details ######################################################################################################
foreach($item in $HyperVJobs) {

    $JobResult.Name = $item.Name

    # Load details
    $Job     = Get-VBRJob -Name $item.name
    $Session = Get-VBRSession -Job $job -Last
    $Tasks   = Get-VBRTaskSession -Session $Session

    # Check results
    $JobResult = Get-TaskResult $Tasks
    $JobResult = Get-SessionState $Session $JobResult
    $JobResult.LastBkp = (New-TimeSpan -Start $Session.CreationTime -End (Get-Date)).Hours
    $CheckJobError = Get-TaskLog $Tasks
    $CheckJobError += Get-SessionLog $Session
    if ($CheckJobError) { $JobResult.Text = $CheckJobError }

    # Create XML
    Set-XMLContent -JobResult $JobResult -HoursSince $HoursSince
}

#### Get SimpleBackupCopy Bckup details ######################################################################################################
foreach($item in $SimpleBackupCopyJobs) {

    $JobResult.Name = $item.Name

     # Load details
    $Job = Get-VBRJob -Name $item.Name
    $Worker = $job.GetWorkerJobs() 
    $Session = $Worker.FindLastSession()

    # Check results
    $JobResult = Get-TaskResult $Session
    $JobResult = Get-SessionState $Session $JobResult
    $JobResult.LastBkp = (New-TimeSpan -Start $Session.CreationTime -End (Get-Date)).Hours
    $CheckJobError = Get-TaskLog $Tasks
    $CheckJobError += Get-SessionLog $Session
    if ($CheckJobError) { $JobResult.Text = $CheckJobError }
     
    # Create XML
    Set-XMLContent -JobResult $JobResult -HoursSince $HoursSince
}

#### Get TapeJob details ########################################################################################################
foreach($item in $TapeJobs) {

    $JobResult.Name = $item.Name

    # Load details
    $obVBRSession = Get-VBRTapeJob | Where-Object { ( $_.Name -like $item.Name ) }
    $Session      = Get-VBRSession -Job $obVBRSession -Last
    $Tasks        = Get-VBRTaskSession -Session $Session

    # Check results
    $JobResult = Get-TaskResult $Tasks
    $JobResult = Get-SessionState $Session $JobResult
    $JobResult.LastBkp = (New-TimeSpan -Start $Session.CreationTime -End (Get-Date)).Hours
    $CheckJobError = Get-TaskLog $Tasks
    $CheckJobError += Get-SessionLog $Session
    if ($CheckJobError) { $JobResult.Text = $CheckJobError }

    # Create XML
    Set-XMLContent -JobResult $JobResult -HoursSince $HoursSince

}

#### Get Linux-Agent Job details ################################################################################################
foreach($item in $LinuxAgentJobs) {

    $JobResult.Name = $item.Name

    # Load details
    $Job     = Get-VBREPJob -Name $item.name
    $Session = Get-VBRSession -Job $Job -Last
    $Tasks   = Get-VBRTaskSession -Session $Session

    # Check Session results
    $JobResult = Get-TaskResult $Tasks
    $JobResult = Get-SessionState $Session $JobResult
    $JobResult.LastBkp = (New-TimeSpan -Start $Session.CreationTime -End (Get-Date)).Hours
    $CheckJobError = Get-TaskLog $Tasks
    $CheckJobError += Get-SessionLog $Session
    if ($CheckJobError) { $JobResult.Text = $CheckJobError }

    # Create XML
    Set-XMLContent -JobResult $JobResult -HoursSince $HoursSince
}

#### Get NAS Job details ##################################################################################################
foreach($item in $NASJobs) {

    $JobResult.Name = $item.Name

    # Load details
    $Job     = Get-VBRJob -Name $item.name
    $Session = Get-VBRSession -Job $job -Last
    $Tasks   = Get-VBRTaskSession -Session $Session

    # Check Session results
    $JobResult = Get-TaskResult $Tasks
    $JobResult = Get-SessionState $Session $JobResult
    $JobResult.LastBkp = (New-TimeSpan -Start $Session.CreationTime -End (Get-Date)).Hours
    $CheckJobError = Get-TaskLog $Tasks
    $CheckJobError += Get-SessionLog $Session
    if ($CheckJobError) { $JobResult.Text = $CheckJobError }
    
    # Create XML
    Set-XMLContent -JobResult $JobResult -HoursSince $HoursSince
}

#### Get Windows-Agent Job details ##############################################################################################
foreach($item in $WinAgentJobs) {

    $JobResult.Name = $item.Name

    # Load details
    $Job     = Get-VBRJob -Name $item.name
    $Session = Get-VBRSession -Job $job -Last
    $Tasks   = Get-VBRTaskSession -Session $Session

    # Check Session results
    $JobResult = Get-TaskResult $Tasks
    $JobResult = Get-SessionState $Session $JobResult
    $JobResult.LastBkp = (New-TimeSpan -Start $Session.CreationTime -End (Get-Date)).Hours
    $CheckJobError = Get-TaskLog $Tasks
    $CheckJobError += Get-SessionLog $Session
    if ($CheckJobError) { $JobResult.Text = $CheckJobError }

    # Create XML
    Set-XMLContent -JobResult $JobResult -HoursSince $HoursSince
}

#### Get BackupCopyJob details ##################################################################################################
foreach($item in $BackupCopyJobs) {

    $JobResult.Name = $item.Name

    # Load details
    $Job     = Get-VBRJob -Name $item.name
    $Session = Get-VBRSession -Job $job -Last
    $Tasks   = Get-VBRTaskSession -Session $Session

    # Check Session results
    $JobResult = Get-TaskResult $Session
    $JobResult = Get-SessionState $Session $JobResult
    $JobResult.LastBkp = (New-TimeSpan -Start $Session.CreationTime -End (Get-Date)).Hours
    $CheckJobError = Get-TaskLog $Tasks
    $CheckJobError += Get-SessionLog $Session
    if ($CheckJobError) { $JobResult.Text = $CheckJobError }

    # Create XML
    Set-XMLContent -JobResult $JobResult -HoursSince $HoursSince
}

#### Get NASCopyJobs details ##################################################################################################
foreach($item in $NASCopyJobs) {

    $JobResult.Name = $item.Name

    # Load details
    $Job     = Get-VBRJob -Name $item.name
    $Session = Get-VBRSession -Job $job -Last
    $Tasks   = Get-VBRTaskSession -Session $Session

    # Check Session results
    $JobResult = Get-TaskResult $Session
    $JobResult = Get-SessionState $Session $JobResult
    $JobResult.LastBkp = (New-TimeSpan -Start $Session.CreationTime -End (Get-Date)).Hours
    $CheckJobError = Get-TaskLog $Tasks
    $CheckJobError += Get-SessionLog $Session
    if ($CheckJobError) { $JobResult.Text = $CheckJobError }

    # Create XML
    Set-XMLContent -JobResult $JobResult -HoursSince $HoursSince
}

#### Get File Copy Job details ##################################################################################################
foreach($item in $FileCopyJobs) {

    $JobResult.Name = $item.Name

   # Load details
   $Job     = Get-VBRJob -Name $item.name
   $Session = Get-VBRSession -Job $job -Last
   $Tasks   = Get-VBRTaskSession -Session $Session

   # Check Session results
   $JobResult = Get-TaskResult $Session
   $JobResult = Get-SessionState $Session $JobResult
   $JobResult.LastBkp = (New-TimeSpan -Start $Session.CreationTime -End (Get-Date)).Hours
   $CheckJobError = Get-TaskLog $Tasks
   $CheckJobError += Get-SessionLog $Session
   if ($CheckJobError) { $JobResult.Text = $CheckJobError }

    # Create XML
    Set-XMLContent -JobResult $JobResult -HoursSince $HoursSince
}