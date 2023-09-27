<#
    .SYNOPSIS
		This script checks the status of all active Veeam Backup & Replication jobs on a backup server.
		It collects detailed information and creates an XML file per backupjob as output.
		The XML will be placeed in C:\Temp\VeeamResults where it can be retreived by the PRTG-Sensor

    .INPUTS
		None

    .OUTPUTS
		The script creates a XML file formated for PRTG.

    .LINK
    https://raw.githubusercontent.com/tn-ict/Public/master/Disclaimer/DISCLAIMER

    .NOTES
		Author:  Andreas Bucher
		Version: 1.0.0
		Date:    27.09.2023
		Purpose: XML-Part of the PRTG-Sensor VeeamBRJobCheck

    .EXAMPLE
		powershell.exe -NoProfile -NoLogo -NonInteractive -ExecutionPolicy Bypass -File "C:\Script\VeeamBRJobCheck-XML.ps1"
		
		Run this script with task scheduler use powershell.exe as program and the parameters as described
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
    pcu      = "GB"
    tsize    = 0
    tcu      = "GB"
    rsize    = 0
    rcu      = "GB"
    usize    = 0
    ucu      = "GB"
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
    $result+=   "  <DecimalMode>Auto</DecimalMode>" + $nl
    $result+=   "  <CustomUnit>$($JobResult.pcu)</CustomUnit>" + $nl
    $result+=   "  <showChart>1</showChart>" + $nl
    $result+=   "  <showTable>1</showTable>" + $nl
    $result+=   "</result>" + $nl

    $result+=   "<result>" + $nl
    $result+=   "  <channel>Gelesen</channel>" + $nl
    $result+=   "  <value>$($JobResult.rsize)</value>" + $nl
    $result+=   "  <Float>1</Float>" + $nl
    $result+=   "  <DecimalMode>Auto</DecimalMode>" + $nl
    $result+=   "  <CustomUnit>$($JobResult.rcu)</CustomUnit>" + $nl
    $result+=   "  <showChart>1</showChart>" + $nl
    $result+=   "  <showTable>1</showTable>" + $nl
    $result+=   "</result>" + $nl

    $result+=   "<result>" + $nl
    $result+=   "  <channel>Transferiert</channel>" + $nl
    $result+=   "  <value>$($JobResult.tsize)</value>" + $nl
    $result+=   "  <Float>1</Float>" + $nl
    $result+=   "  <DecimalMode>Auto</DecimalMode>" + $nl
    $result+=   "  <CustomUnit>$($JobResult.tcu)</CustomUnit>" + $nl
    $result+=   "  <showChart>1</showChart>" + $nl
    $result+=   "  <showTable>1</showTable>" + $nl
    $result+=   "</result>" + $nl

    $result+=   "<result>" + $nl
    $result+=   "  <channel>Belegt</channel>" + $nl
    $result+=   "  <value>$($JobResult.usize)</value>" + $nl
    $result+=   "  <Float>1</Float>" + $nl
    $result+=   "  <DecimalMode>Auto</DecimalMode>" + $nl
    $result+=   "  <CustomUnit>$($JobResult.ucu)</CustomUnit>" + $nl
    $result+=   "  <showChart>1</showChart>" + $nl
    $result+=   "  <showTable>1</showTable>" + $nl
    $result+=   "</result>" + $nl

    $result+=   "<result>" + $nl
    $result+=   "  <channel>Dauer</channel>" + $nl
    $result+=   "  <value>$($JobResult.Duration)</value>" + $nl
    $result+=   "  <Float>1</Float>" + $nl
    $result+=   "  <DecimalMode>Auto</DecimalMode>" + $nl
    $result+=   "  <CustomUnit>Min</CustomUnit>" + $nl
    $result+=   "  <showChart>1</showChart>" + $nl
    $result+=   "  <showTable>1</showTable>" + $nl
    $result+=   "</result>" + $nl

    $result+=   "<result>" + $nl
    $result+=   "  <channel>Durchsatz</channel>" + $nl
    $result+=   "  <value>$($JobResult.avgspeed)</value>" + $nl
    $result+=   "  <Float>1</Float>" + $nl
    $result+=   "  <DecimalMode>Auto</DecimalMode>" + $nl
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
    $result+=   "  <LimitWarningMsg>Backup-Job älter als 24h</LimitWarningMsg>" + $nl
    $result+=   "  <LimitMaxError>$ErrorLevel</LimitMaxError>" + $nl
    $result+=   "  <LimitErrorMsg>Backup-Job älter als 36h</LimitErrorMsg>" + $nl
    $result+=   "  <LimitMode>1</LimitMode>" + $nl
    $result+=   "</result>" + $nl

    $result+= "</prtg>" + $nl

    # Write XML-File
    if(-not (test-path $resultFolder)){ New-Item -Path $resultFolder -ItemType Directory }
    $xmlFilePath = "$resultFolder\$($JobResult.Name).xml"
    $result | Out-File $xmlFilePath -Encoding utf8

}

# Get Backupjob Details
function Get-BackupJobDetails {
    param (
        $Job
    )

    # Get backupjob name
    $JobResult.Name = $Job.Name

    # Get last active session
    # Immediate Backup Copy without idle state
    if ($Job.JobType -eq "SimpleBackupCopyPolicy") {
        $Worker  = $Job.GetWorkerJobs() 
        $Session = [Veeam.Backup.Core.CBackupSession]::GetByJob($Worker.id) | Where-Object { $_.State -notmatch "Idle" }  | Sort-Object -Property Creationtime -Descending | Select-Object -First 1
    }
    # Legacy Backup Copy without idle state
    # Activate if no data is returned for Legacy Backup Copy Jobs
    #elseif ($Job.JobType -eq "BackupSync") { 
    #    $Session = Get-VBRSession -Job $Job | where-object { $_.State -ne "idle" } | Sort-Object -Property Creationtime -Descending | Select-Object -First 1
    #}
    # Everything else
    else {
        $Session = Get-VBRSession -Job $Job -Last
    }

    # Get Tasks from Session
    $Tasks = Get-VBRTaskSession -Session $Session

    # Get hours since last backup
    $JobResult.LastBkp = (New-TimeSpan -Start $Session.CreationTime -End (Get-Date)).Hours

    # Check Session results
    $JobResult = Get-SessionState -Session $Session

    # Get Task resultst
    # Immediate Backup Copy
    if ($Job.JobType -eq "SimpleBackupCopyPolicy" ) {
        $JobResult = Get-TaskResult -Tasks $Session
    }
    # Everything else
    else {
        $JobResult = Get-TaskResult -Tasks $Tasks
    }

    # Check for log messages
    # Immediate Backup Copy
    if ($Job.JobType -eq "SimpleBackupCopyPolicy") {
        $JobLog  = Get-TaskLog -Tasks $Session
    }
    # Everything else
    else {
        $JobLog  = Get-TaskLog -Tasks $Tasks
    }
    $JobLog += Get-SessionLog -Session $Session
    if ($JobLog) { $JobResult.Text = $JobLog }

    # Create XML
    Set-XMLContent -JobResult $JobResult
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
    [float]$avgspeed = 0
    [float]$percent  = 0

    # Get details from each task
    foreach ($task in $Tasks) {
        $countobj += $task.Progress.ProcessedObjects
        $rsize    += $task.Info.Progress.ReadSize
        $tsize    += $task.Info.Progress.TransferedSize
        $psize    += $task.Info.Progress.ProcessedSize
        $usize    += $task.Info.Progress.TotalUsedSize
        if ( -not ($task.Info.Progress.AvgSpeed -eq 0)) { $avgspeed += $task.Info.Progress.AvgSpeed; $countspeed++ }
        if ($task.Progress.Percents -lt 100) {$percent += $task.Progress.Percents}
    }

    # Fill JobResult
    if ($Tasks.Count -ne 1) {$JobResult.countobj = $Tasks.Count}
    else {$JobResult.countobj = $countobj}
    
    $JobResult.avgspeed = ($avgspeed/$countspeed)/1MB
    $JobResult.percent  = $percent

    $JobResult.rsize = $rsize/1GB
    $JobResult.tsize = $tsize/1GB
    $JobResult.psize = $psize/1GB
    $JobResult.usize = $usize/1GB

    Return $JobResult
}

# Check backupjob status
function Get-SessionState {
    param(
        $Session
    )

    # Check if Session has a percentage state
    if ($Session.Progress -is [int] -and $JobResult.Percent -eq 0) { $JobResult.Percent = $Session.Progress }
    $percent = $JobResult.Percent -replace '[^0-9"."]',''

    # Get Job duration
    if ($Session.EndTime) {$JobResult.duration = [Math]::Round((New-TimeSpan -Start $Session.CreationTime -End $Session.EndTime).TotalMinutes,0)}
    else {$JobResult.duration = [Math]::Round((New-TimeSpan -Start $Session.CreationTime -End (Get-Date)).TotalMinutes,0)}

    # Get job results and define result parameters
    if     ($Session.Result -eq "Success")        { $JobResult.Value = 1; $JobResult.Warning = 0; $JobResult.Error = 0; $JobResult.Text = "BackupJob $($JobResult.Name) erfolgreich" }
    elseif ($Session.Result -eq "Warning")        { $JobResult.Value = 2; $JobResult.Warning = 1; $JobResult.Error = 0; $JobResult.Text = "BackupJob $($JobResult.Name) Warnung. Bitte pr&#252;fen" }
    elseif ($Session.Result -eq "Failed")         { $JobResult.Value = 3; $JobResult.Warning = 0; $JobResult.Error = 1; $JobResult.Text = "BackupJob $($JobResult.Name) fehlerhaft" }
    elseif ($Session.State  -eq "Working")        { $JobResult.Value = 2; $JobResult.Warning = 1; $JobResult.Error = 0; $JobResult.Text = "BackupJob $($JobResult.Name) l&#228;uft noch: $percent %"  }
    elseif ($Session.State  -eq "Postprocessing") { $JobResult.Value = 2; $JobResult.Warning = 1; $JobResult.Error = 0; $JobResult.Text = "BackupJob $($JobResult.Name) Nachbearbeitung" }
    elseif ($Session.State  -eq "WaitingTape")    { $JobResult.Value = 2; $JobResult.Warning = 1; $JobResult.Error = 0; $JobResult.Text = "BackupJob $($JobResult.Name) wartet auf Tape" }
    elseif ($Session.State  -eq "Idle")           { $JobResult.Value = 1; $JobResult.Warning = 0; $JobResult.Error = 0; $JobResult.Text = "BackupJob $($JobResult.Name) idle" }
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

#-----------------------------------------------------------[Execute]------------------------------------------------------------
# Get Backup Jobs 
$BackupJobs = Get-VBRJob | where-object { $_.IsScheduleEnabled -and $_.JobType -eq "Backup" }

# Get Tape Jobs
$Tapejobs = Get-VBRTapeJob | where-object { $_.Enabled }

# Get NAS Jobs
$NASJobs = Get-VBRJob | where-object { $_.IsScheduleEnabled -and $_.JobType -eq "NasBackup" }

# Get Windows Agent Jobs
$WinAgentJobs = Get-VBRComputerBackupJob | where-object { $_.JobEnabled }

# Get Linux Agent Jobs
$LinuxAgentJobs = Get-VBREPJob | where-object { $_.IsEnabled }

# Get Backup Copy Jobs
$BackupCopyJobs = Get-VBRJob | where-object { $_.IsScheduleEnabled -and $_.JobType -eq "BackupSync" }

# Get NAS Copy Jobs
$NASCopyJobs = Get-VBRJob | where-object { $_.IsScheduleEnabled -and $_.JobType -eq "NasBackupCopy" }

# Get File Copy Jobs
$FileCopyJobs = Get-VBRJob | where-object { $_.IsScheduleEnabled -and $_.JobType -eq "Copy" }

# Get Simple Backup Copy Jobs
$SimpleBackupCopyJobs = Get-VBRJob | where-object { $_.IsScheduleEnabled -and $_.JobType -eq "SimpleBackupCopyPolicy" }

#### Get Backup Job details #####################################################################################################
foreach($item in $BackupJobs)           { Get-BackupJobDetails -Job $item }
foreach($item in $TapeJobs)             { Get-BackupJobDetails -Job $item }
foreach($item in $NASJobs)              { Get-BackupJobDetails -Job $item }
foreach($item in $WinAgentJobs)         { Get-BackupJobDetails -Job $item }
foreach($item in $LinuxAgentJobs)       { Get-BackupJobDetails -Job $item }
foreach($item in $BackupCopyJobs)       { Get-BackupJobDetails -Job $item }
foreach($item in $NASCopyJobs)          { Get-BackupJobDetails -Job $item }
foreach($item in $FileCopyJobs)         { Get-BackupJobDetails -Job $item }
foreach($item in $SimpleBackupCopyJobs) { Get-BackupJobDetails -Job $item }
