<#
    .SYNOPSIS
    This script opens a PS-Drive to check for XML files created through VeeamBRJobCheck-XML.ps1.
    This Script is meant to be used as PRTG custom sensor.

    .PARAMETER HostName
    HostName where the XML is located.
    This parameter is mandantory.

    .PARAMETER JobName
    JobName of the Veeam Backup & Replication backupjob to be monitored
    This parameter is mandantory.

    .PARAMETER UserName
    UserName to connect to the server where the xml is located
    This parameter is optional.

    .PARAMETER Password
    Password to connect to the server where the xml is located
    This parameter is optional.

    .INPUTS
    None

    .OUTPUTS
    This script retrives an xml file and parses it to PRTG

    .LINK
    https://raw.githubusercontent.com/tn-ict/Public/master/Disclaimer/DISCLAIMER

    .NOTES
    Author  : Andreas Bucher
    Version : 0.9.2
    Purpose : XML-Part of the PRTG-Sensor VeeamBRJobCheck

    .EXAMPLE
    Create a Sensor in PRTG with the parameters as following
    -HostName '%host' -JobName 'Jobname' -UserName '%windowsdomain\%windowsuser' -Password '%windowspassword'
    Those %-parameters are retreived from the PRTG WebGUI

    Try it standalone
    .\VeeamBRJobCheck-PRTG.ps1 -JobName "Jobname" -HostName "Host" -UserName "domain\username" -Password "password"

#>
#----------------------------------------------------------[Declarations]----------------------------------------------------------
# Declare input parameters
Param(
    [Parameter(Mandatory=$true)]
    [string]$HostName,
    [Parameter(Mandatory=$true)]
    [string]$Jobname,
    [string]$UserName,
    [string]$Password
    )

# Set encoding to UTF-8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[cultureinfo]::CurrentUICulture = 'de-CH'

# Variables
$rootpath  = "\\$HostName\c$\Temp\VeeamResults"
$resultxml = "$Jobname.xml"
$nl        = [Environment]::NewLine
#-----------------------------------------------------------[Functions]------------------------------------------------------------
# Return Error-XML
function Set-ErrorXML {
    param(
        $msg
    )

    $ErrorXML  = ""
    $ErrorXML += '<?xml version="1.0" encoding="UTF-8" ?>' + $nl
    $ErrorXML += "<prtg>" + $nl
    $ErrorXML += "<error>1</error>" + $nl
    $ErrorXML += "<text>$msg</text>" + $nl
    $ErrorXML += "</prtg>" + $nl

    return $ErrorXML
    exit 1
}
#-----------------------------------------------------------[Execute]------------------------------------------------------------
# Check if HostName was passed
if ( -NOT "$HostName" ) { Set-ErrorXML "Kein Hostname als Parameter definiert" }

# Use SMB if UserName and Password were not passed. Assume the servers are Members of the same domain
if ( -NOT ($UserName -AND $Password) ) { $xmlResultPath = "$rootpath" }

# Use a PowerShell Drive if username and password were passed
elseif ( $UserName -AND $Password )
{
    $secpassword = ConvertTo-SecureString $Password -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential ($UserName, $secpassword)

    New-PSDrive -Credential $cred -Name PS-VeeamResults -PSProvider FileSystem -Root $rootpath
    $xmlResultPath = "PS-VeeamResults:"
}

# Throw an error if the above statements are not met
else { Set-ErrorXML "Server $HostName nicht erreichbar. Benutzer- & Passwort Parameter prüfen..." }

# Throw an error if the result path is not reachable
if ( -NOT (Test-Path -Path "$xmlResultPath")) { Set-ErrorXML "Share $xmlResultPath nicht erreichbar..." }

# Throw error if the result xml is not present
elseif ( -NOT (Test-Path -Path "$xmlResultPath\$resultxml")) { Set-ErrorXML "$resultxml auf Share $xmlResultPath nicht vorhanden..." }

# Throw an error if the result xml is older than 6 hours
elseif ( -NOT (Test-Path -Path "$xmlResultPath\$resultxml" -NewerThan (Get-Date).AddHours(-6) )) { Set-ErrorXML "$resultxml auf Share $xmlResultPath älter als 36h, Task Scheduler prüfen." }

# You want to land here
elseif( $xmlContent = Get-Content -Path "$xmlResultPath\$resultxml" ) { return $xmlContent }

# Throw an unknown error
else { Set-ErrorXML "Unbekannter Fehler im Script $($MyInvocation.InvocationName)" }

# Close the PS-Drive if it was used
If (Test-Path PS-VeeamResults) { Remove-PSDrive -Name PS-VeeamResults }