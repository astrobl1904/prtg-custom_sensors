<#
    .SYNOPSIS
        PRTG Advanced Scheduled Task Sensor for Talend Open Studio ETL Jobs and Log files.

    .DESCRIPTION
        This Advanced Sensor will report Task statistics based on Windows Scheduled Task and
        error entries it found in a XML log file maintained by the Talend orchestration job.

        This script performs two tests: it checks for the periodic execution of the defined
        Windows Scheduled Task and looks for error entries in the Talend Job maintained log file.

        Additionally this Advanced Sensor script allows to monitor whether the Windows task
        is disabled. In this case an error will be reported back to the probe.

        If the task finished successfully the script verifies if any Java exception log files
        exist in the log directory (specified in the Talend Orchestration settings). If there
        are no log files present the most recent execution of the Talend job succeeded.
        If there are exception log files present the content of the file (based on the value
        of the CorrelationID) will be read, examined, and a summary will be shown in the sensor's
        <text> element.

    .PARAMETER ComputerName
        Specifies the computer on which the command runs. The default is the local computer.
    
    .PARAMETER SensorName
        Specifies the name of the PRTG sensor.

    .PARAMETER TaskName
        Specifies a name of a scheduled task for Talend Open Studio.
    
    .PARAMETER TaskPath
        Specifies a path for scheduled tasks in Task Scheduler namespace. You can use \ for
        the root folder. If you do not specify a path, the cmdlet uses the root folder.

    .PARAMETER WindowsUser
        Specifies the username that authenticates the PSSession. If required pass
        on PRTG parameter %windowsuser.

    .PARAMETER WindowsPassword
        Specifies the password to authenticate the PSSession. If required pass on PRTG
        parameter %windowspassword. Do not provide this value on the commandline
        use -WindowsCredential instead.
    
    .PARAMETER WindowsCredential
        Specifies a PSCredential object to authenticate the PSSession.

    .PARAMETER TalendLogFile
        Specifies an absolute literal path to a file a Talend Job logs its START-END events to.
    
    .PARAMETER TalendJobNamespace
        Specifies the namespace in domain reverse order.
    
    .NOTES
        PRTG has limited parameter parsing capabilities. This has immediate effects on how to
        enter paths in the sensor definition. Escaping with backslash only works in conjunction
        with quotes but not with the backslash itself. In all path paramters (TaskPath, LogFile)
        the forward slash has to be used. In the sensor script this will be replaced with backslash
        as required.

        Author: Andreas Strobl <astroblx@asgraphics.at>
        Date: 2022-03-26

    .LINK
        PRTG Manual - Custom Sensors: https://www.paessler.com/manuals/prtg/custom_sensors#advanced_sensors
    .LINK
        PRTG Manual - Custom Sensor, Advanced Elements: https://www.paessler.com/manuals/prtg/custom_sensors#advanced_elements
    .LINK
        Markus Kraus - MY CLOUD (R)EVOLUTION: https://mycloudrevolution.com/de/2016/09/15/prtg-advanced-scheduled-task-sensor/
#>


[CmdletBinding(DefaultParameterSetName = 'Sensor')]
param (
    [Parameter(Position=0,
        ParameterSetName = 'Sensor',
        HelpMessage="Specifies the computer on which the command runs. The default is the local computer.")]
    [Alias("CN")]
    [string]
    $ComputerName = $env:COMPUTERNAME,
    [Parameter(Mandatory, Position=1,
        ParameterSetName = 'Sensor',
        HelpMessage="Specifies a name of a scheduled task for Talend Open Studio.")]
    [string]
    $TaskName,
    [Parameter(
        ParameterSetName = 'Sensor',
        HelpMessage="Specifies a path for scheduled tasks in Task Scheduler namespace. You can use \ for the root folder. If you do not specify a path, the cmdlet uses the root folder.")]
    [string]
    $TaskPath = "\",
    [Parameter(Mandatory,
        ParameterSetName = 'Sensor',
        HelpMessage="Specifies the name of the PRTG sensor.")]
    [string]
    $SensorName,
    [Parameter(
        ParameterSetName = 'Sensor',
        HelpMessage="Specifies the username that authenticates the PSSession. If required pass on PRTG parameter %windowsuser.")]
    [string]
    $WindowsUser,
    [Parameter(
        ParameterSetName = 'Sensor',
        HelpMessage="Specifies the password to authenticate the PSSession. If required pass on PRTG parameter %windowspassword. Do not provide this value on the commandline use -WindowsCredential instead.")]
    [SecureString]
    $WindowsPassword,
    [Parameter(
        ParameterSetName = 'Sensor',
        HelpMessage="Specifies a PSCredential object to authenticate the PSSession.")]
    [System.Management.Automation.PSCredential]
    $WindowsCredential,
    [Parameter(
        ParameterSetName = 'Sensor',
        HelpMessage="Specifies an absolute literal path to a file a Talend Job logs its START-END events to.")]
    [Alias('TalendLogFile')]
    [string]
    $LogFile,
    [Parameter(
        ParameterSetName = 'Sensor',
        HelpMessage="Specifies the Talend Namespace of the log file in reverse doted form along with the job identifier."
    )]
    [string]
    $TalendJobNamespace = 'com.example.talend.jobns',
    [Parameter(Mandatory,
        ParameterSetName = 'Version',
        HelpMessage = "Shows the version of this script and exits.")]
    [switch]
    $Version
)

$_VERSION = '1.0.0'
$_SCRIPTNAME = 'Get-TalendScheduledTask.ps1'
$_AUTHOR = 'Andreas Strobl <astroblx@asgraphics.at>'

#region Main
function Main {
    # BASIC SENSOR SETUP - Throws exepctions -> Creats PrtgError object
    [bool]$_withPSSession = If ($LogFile.Length -gt 0) {$true} else {$false}
    [PrtgSensorType]$_prtgSensorType = if ($LogFile.Length -gt 0) {
        [PrtgSensorType]::TalendScheduledTask} else {
        [PrtgSensorType]::Generic
    }
    [System.Management.Automation.Runspaces.PSSession]$_prtgSession = $null
    [Microsoft.Management.Infrastructure.CimSession]$_prtgCimSession = $null

    try {
        # Create required sessions
        Write-Verbose ("Create new sessions to remote host...")
        ($_prtgCimSession, $_prtgSession) = New-PrtgSessions -WithPSSession:$_withPSSession

        # Get Scheduled Task object - throw exception if -TaskName specifies multiple objects
        Write-Verbose ("Retrieve specified Scheduled Task CIM object...")
        [string]$_taskPath = $TaskPath -replace '/', '\'
        $_talendScheduledTask = Get-ScheduledTask -CimSession $_prtgCimSession -TaskName $TaskName -TaskPath $_taskPath -ErrorAction Stop -ErrorVariable _cim_error
        if ($_talendScheduledTask.Count -gt 1) {
            throw [System.Management.Automation.GetValueException]::new("The WMI query returned more than one ScheduledTask object.")
        }

        # Create PRTG sensor
        Write-Verbose ("Instantiating new Talend Scheduled Task Custom Sensor...")
        $_prtgSensor = [PrtgSensor]::new($SensorName, $_prtgSensorType)
        $_prtgSensor.SetTaskMetricData($_talendScheduledTask)

        # Process Talend Logfile and error xml files
        if ($LogFile.Length -gt 0) {
            if ($TalendJobNamespace.Length -eq 0) {
                throw "Talend Job Namespace is missing and is required for processing Talend Logs."
            }
            
            $_talendLogContent = Get-TalendLogContent -Session $_prtgSession -Path $LogFile
            if ($null -eq $_talendLogContent) {
                throw [System.IO.FileNotFoundException] "Get-TalendLogContent: Cannot find path '$($LogFile)' because it does not exist."
            }
            Write-Verbose ("Instantiating new Talend Log Container...")
            $_prtgSensor.TalendLog = [TalendLog]::new($_talendLogContent, $TalendJobNamespace)

            if ($_prtgSensor.TalendLog.InnerExceptionRequired()) {
                $_exceptionFilename = $_prtgSensor.TalendLog.GetInnerExceptionLogFilename()
                $_exceptionLogPath = Join-Path -Path (Split-Path $LogFile -Parent) -ChildPath $_exceptionFilename
    
                $_exceptionLogContent = Get-TalendLogContent -Session $_prtgSession -Path $_exceptionLogPath
                # Check whether file is required or not and throw exception as necessary
                # Handle preliminary check of result of log file
                if ($_prtgSensor.TalendLog.GetLastRunResult() -eq -128 -and $null -eq $_exceptionLogContent) {
                    throw [System.IO.FileNotFoundException] "Get-TalendLogContent (-128): Cannot find path '$($_exceptionLogPath)' because it does not exist."
                }
                if ($_prtgSensor.TalendLog.GetLastRunResult() -eq -64 -and $null -eq $_exceptionLogContent) {
                    $_prtgSensor.TalendLog.ConfirmLastRunResult()
                } else {
                    $_prtgSensor.TalendLog.ImportInnerException($_exceptionLogContent)
                }
            }
            Write-Verbose ("Analysing Talend Log Events...")
            $_prtgSensor.TalendLog.AnalyseTalendLog()
        }

        Write-Verbose ("Merge/Fuse Task Metric with Sensor Channels, write PRTG XML to host output...")
        $_prtgSensor.MergeChannelData()
        $_prtgSensor.WritePrtgXml()

    }
    catch [System.Management.Automation.GetValueException] {
        $prtg_error = [PrtgError]::new(1, $PSItem.Exception.ToString())
        $prtg_error.StackTrace = @("Sensor Parameter Data: {", "TaskName:", $TaskName, "/ TaskPath:", $TaskPath, "}") -join " "
        $prtg_error.WritePrtgXml()
    }
    catch [Microsoft.PowerShell.Cmdletization.Cim.CimJobException] {
        $_message = ''
        if ($null -eq $_cim_error) {
            $_message = $PSItem.Exception.ToString()
        } else {
            $_message = $_cim_error.ErrorRecord.Exception.ToString()
        }
        $prtg_error = [PrtgError]::new(1, $_message)
        $prtg_error.StackTrace = @("Sensor Parameter Data: {", "TaskName:", $TaskName, "/ TaskPath:", $TaskPath, "}") -join " "
        $prtg_error.WritePrtgXml()
    }
    catch [Microsoft.Management.Infrastructure.CimException]  {
        $_message = ''
        if ($null -eq $_cim_error) {
            $_message = $PSItem.Exception.ToString()
        } else {
            $_message = $_cim_error.ErrorRecord.Exception.ToString()
        }
        $prtg_error = [PrtgError]::new(1,$_message)
        $prtg_error.WritePrtgXml()
    }
    catch [System.IO.FileNotFoundException] {
        $prtg_error = [PrtgError]::new(1, $PSItem.Exception.ToString())
        $prtg_error.WritePrtgXml()
    }
    catch {
        $prtg_error = [PrtgError]::new(1, $PSItem.Exception.ToString())
        $prtg_error.WritePrtgXml()
    }
    finally {
        # Cleanup sessions
        if ($null -ne $_prtgCimSession) {
            Write-Verbose ("$_SCRIPTNAME - Remove CIMSession")
            Remove-CimSession $_prtgCimSession
        }
        # Cleanup sessions
        if ($null -ne $_prtgSession) {
            Write-Verbose ("$_SCRIPTNAME - Remove PSSession")
            Remove-PSSession $_prtgSession
        }
    }
}
#endregion Main

#region Functions
function New-PrtgSessions() {
    <#
    .DESCRIPTION
    New-PrtgSessions saves the required session objects in variables $global:_prtgSession and $global:_prtgCimSession.

    Get-TalendScheduledTask.ps1 requires two different sessions since a PSSession is required for file handling
    and a CimSession is required for Windows OS component handling - e.g. for ScheduledTask objects.

    Returns single objects of types CimSession, PSSession in that order.
    #>
    [CmdletBinding()]
    param (
        [Parameter(
            HelpMessage="Specifies that a PSSession is required."
        )]
        [switch]
        $WithPSSession
    )

    process {
        [pscredential]$_windowsCredential = $null
        [System.Management.Automation.Runspaces.PSSession]$_psSession = $null
        [Microsoft.Management.Infrastructure.CimSession]$_cimSession = $null
        $_cimSessionOption = New-CimSessionOption -UseSsl
    
        # Verify credential paramters
        if ($WindowsUser.Length -gt 0 -and $null -ne $WindowsPassword) {
            $_windowsCredential = [System.Management.Automation.PSCredential]::new($WindowsUser, $WindowsPassword) 
        }
        if ($null -ne $WindowsCredential) {
            $_windowsCredential = $WindowsCredential
        }
    
        # Create a new CimSession
        Write-Verbose ("New-PrtgSessions - Create a new CimSession to host '$ComputerName'.")
        if ($null -eq $_windowsCredential) {
            # Connect with inherited credentials
            Write-Verbose ("  - with inherited credentials")
            $_cimSession = New-CimSession -ComputerName $ComputerName -Name $SensorName -SessionOption $_cimSessionOption -ErrorAction Stop -ErrorVariable _cim_error
        } else {
            # Connect with provided credentials
            Write-Verbose ("  - with provided credentials")
            $_cimSession = New-CimSession -ComputerName $ComputerName -Name $SensorName -SessionOption $_cimSessionOption -Credential $_windowsCredential -ErrorAction Stop -ErrorVariable _cim_error
        }
    
        # Optionally create a new PSSession for none-WMI operations
        if ($WithPSSession) {
            Write-Verbose ("New-PrtgSessions - Create a new PSSession to host '$ComputerName'.")
            if ($null -eq $_windowsCredential) {
                # Connect with inherited credentials
                Write-Verbose ("  - with inherited credentials")
                $_psSession = New-PSSession -ComputerName $ComputerName -Name $SensorName -UseSSL -ErrorAction Stop
            } else {
                # Connect with provided credentials
                Write-Verbose ("  - with provided credentials")
                $_psSession = New-PSSession -ComputerName $ComputerName -Name $SensorName -UseSSL -Credential $_windowsCredential -ErrorAction Stop
            }
        }
        ($_cimSession, $_psSession)
    }
}

function Get-TalendLogContent() {
    <#
    .DESCRIPTION
        Get-TalendLogContent - Gets the content of the specified Talend Log File as XML

    .NOTES
        Get-TalendLogContent is implemented with pipelining support. An initial implementation
        let the Invoke-Command cmdlet throw an exception if the file couldn't be found. Since
        this function is used for the mandatory logfile AND for the optional exception file in both
        cases it threw an exception if the file could not be found.

        There exists one case though, where the exception file is optional: when it was created
        by throwing an user-defined warning or error event and not caused by an Java exception.
        In this case we must not cause the function to throw a not-found-exception but rather
        return no content at all and let the caller handle this situation.

        In the later implementation -ErrorAction has been changed from `Stop` to `SilentlyContinue`.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position=0,
            HelpMessage="Specifies the PSSession to be used."
        )]
        [System.Object]
        $Session,
        [Parameter(Mandatory, Position=1,
            HelpMessage="Specifies the LiteralPath of the Talend Log file.")]
        [string]
        $Path
    )
    process {
        $_content = $null
        [bool]$fileExists = Invoke-Command -Session $Session -ScriptBlock {Test-Path -Path $Using:Path} -ErrorAction SilentlyContinue
        if ($fileExists) {
            $_file_size = Invoke-Command -Session $Session -ScriptBlock {(Get-Item -Path $Using:Path).Length} -ErrorAction Stop
            Write-Verbose ("   - Fetch content of Talend Job logfile '$Path' ($_file_size).")
            $_content = Invoke-Command -Session $Session -ScriptBlock {Get-Content -Path $Using:Path} -ErrorAction Stop    
        }

       $_content
    }
}
#endregion Functions

#region Enumerations
enum PrtgSensorType {
    Generic = 1
    TalendScheduledTask = 2
}
#endregion Enumerations

#region Classes
class TalendLog {
    <#
    .DESCRIPTION
        Class TalendLog contains all the handling of the primary Talend Job log and an optional exception
        log created by a subjob triggered with component tLogCatcher.

        The class is instantiated with the content of the primary orchestration log and the namespace of
        the Talend orchestration job (in reverse dotted notation; e.g. com.example.talend.projectid.jobid).
        
        The Talend subjob providing the attributes for the XML dump writes the namespace parted as leaf and parent
        in multiple child nodes within node <Event>.

    .NOTES
        Methods `InnerExceptionRequired` can be used to detect whether or not the exception log has been imported
        with `ImportInnerException`. Initially, property LastRunResult has the value -1 indicating that the
        logfile has not been analysed. Calling `GetLastRunResult` in this state the logfile will be analysed
        and based on the following events determined:

            * Preliminary Success: Presence of Event ID 200 and Event ID 201: LastRunResult => -64
            * Preliminary Failed: Presence of Event ID 200, missing Event ID 201: LastRunResult => -128
            * Sucess: Confirmed with method `ConfirmLastRunResult`: LastRunResult => 0
            * Failed: Confirmed by `AnalyseTalendLog` called by `GetLastRunResult`: LastRunResult => >0
        
        A preliminary state is required since warnings in an optional exception file might exist and still
        have had the event IDs 200 and 201 been written in the primary log file.

        With method `ConfirmLastRunResult` a preliminary success state can be either confirmed to success or
        with importing an exception log and calling `GetLastRunResult` again to the state contained in the
        exception log.
        A state of -128 must always be resolved with importing the exception log and a call of `GetLastRunResult`.

    #>

    [ValidateNotNullOrEmpty()][xml]$Content
    [xml]$InnerException
    hidden [string]$Namespace
    hidden [string]$NamespaceParent
    hidden [string]$NamespaceLeaf
    hidden [int]$LastRunResult = -1
    hidden [string]$LastRunCorrelationID
    hidden [string]$StackTrace
    hidden [int]$InnerExceptionCode
    hidden [string]$InnerExceptionMessage


    # Constructors
    TalendLog([string]$content, [string]$namespace) {
        if ($content.Length -eq 0) {
            throw "Content must not null or empty."
        }
        if ($namespace.Length -eq 0) {
            throw "Namespace must not null or empty."
        }
        $this.Content = $content
        $this.Namespace = $namespace
        $this.NamespaceLeaf = ($namespace -split '\.')[-1]
        $this.NamespaceParent = $namespace -replace ".$($this.NamespaceLeaf)", ''
    }

    # Public methods
    [bool]InnerExceptionLoaded() {
        return ($null -ne $this.InnerException)
    }

    [bool]InnerExceptionRequired() {
        # Trigger lazy loading result
        [int]$_lastRunResult = $this.GetLastRunResult()
        return (($_lastRunResult -eq -128 -or $_lastRunResult -eq -64) -and $null -eq $this.InnerException)
    }

    [void]ImportInnerException([string[]]$content) {
        if ($content.Length -eq 0) {
            throw "Content must not be null or empty"
        }
        # Since there are line breaks in the message part of the exception node
        # sanitation is required
        [string[]]$sanitized = @()
        foreach ($line in $content) {
            if (($line -match '^$' -or
                    $line -match '^<\?.*\?>$' -or
                    $line -match "^ *<\/?[^>]+>") -and (-Not ($line -match "^ *<\/Message>"))
            ) {
                $sanitized += $line
            } else {
                # Append to line
                $_count = $sanitized.Count - 1
                $_line = $sanitized[$_count]
                if ($line -match "^ *<\/Message>") {
                    $_sanitized = $_line.Substring(0,250) -replace '&apos;', "'"
                    $_sanitized = $_sanitized -replace '&', "."
                    $_sanitized = $_sanitized -replace '\0', ''
                    $_sanitized += '...'
                    $_sanitized += $line
                    $_line = $_sanitized
                } else {
                    $_line += $line
                }
                $sanitized[$_count] = $_line
            }
        }
        $this.InnerException = ($sanitized -join "`r`n")
        $this.AnalyseTalendLog()
    }

    [int]GetLastRunResult() {
        # return cached values if set, otherwise analyse log, store result
        # in properties and return value (lazy provisioning)
        # Return Codes:
        #   -   -1: Never initialized
        #   -    0: Success
        #   - -128: Failed, inner exception missing/required
        #   -   >0: Failed, return inner exception code
        [int]$_lastRunResult = -128
        if ($this.LastRunResult -ne -1) {
            $_lastRunResult = $this.LastRunResult
        } else {
            # Lazy loading
            $this.AnalyseTalendLog()
            $_lastRunResult = $this.LastRunResult
        }
        return $_lastRunResult
    }

    [void]ConfirmLastRunResult() {
        if ($this.LastRunResult -eq -64) {
            $this.LastRunResult = 0
        }
    }

    [string]GetInnerExceptionLogFilename() {
        [string]$fileName = ""
        # Format DateTime from correlation id
        $corrDateTime = $this.LastRunCorrelationID.Split('-')[1]
        $fileName = @(
            $this.Namespace,
            "$($corrDateTime.Substring(0,8))_$($corrDateTime.Substring(8,4))",
            'xml'
        ) -join '.'
        return $fileName
    }

    [string]GetStackTrace() {
        return $this.StackTrace
    }

    [string]GetInnerExceptionMessage() {
        return $this.InnerExceptionMessage
    }

    [int]GetInnerExceptionCode() {
        return $this.InnerExceptionCode
    }

    # Private Methods
    hidden [void]AnalyseTalendLog() {
        # 1. Search for the most recent event 200 (started) and specified namespaceleaf (source), remember correlation id
        # 2. Search for the most recent event 201 (successfully ended) with the remembered correlation id
        #    - if found: result = -64: preliminary success
        #    - if not found and no inner exception stored - return -128 indicating inner exception required
        #    - if not found and inner exception stored - process inner exception and return code of inner exception
        $logLastStartEvent = $this.Content.Events.Event |
            Sort-Object -Property RecordID -Descending |
            Where-Object {$_.Source -eq $this.NamespaceLeaf -and $_.EventID -eq 200} |
            Select-Object -First 1
        $this.LastRunCorrelationID = $logLastStartEvent.CorrelationID
        $logLastEndEvent = $this.Content.Events.Event |
            Where-Object {$_.CorrelationID -eq $this.LastRunCorrelationID -and $_.EventID -eq 201}

        if ($null -ne $logLastEndEvent -and $this.LastRunResult -eq -1) {
            # Event found -> Successfully finished job - Preliminary Suceess
            $this.LastRunResult = -64
        } else {
            if ($null -eq $this.InnerException) {
                # Require inner exception xml dump if not confirmed and not already called once
                if ($this.LastRunResult -eq -1) {
                    $this.LastRunResult = -128
                }
            } else {
                # Process exception log - should contain either 1 or 2 Event nodes
                $exceptionEvents = $this.InnerException.Events.Event |
                    Sort-Object -Property RecordID -Descending
                if ($exceptionEvents.Count -gt 1) {
                    # contains two nodes - is of type System.Array
                    $this.InnerExceptionCode = $exceptionEvents[1].TalendDataCode
                    $this.LastRunResult = $exceptionEvents[1].TalendDataCode
                    $this.InnerExceptionMessage = $exceptionEvents[1].Message
                    $this.StackTrace = @($exceptionEvents[0].TalendDataObject,
                        $exceptionEvents[0].Message) -join ' -- '
    
                } else {
                    # contains a single node - is of type System.Xml.XmlLinkedNode
                    $this.InnerExceptionCode = $exceptionEvents.TalendDataCode
                    $this.LastRunResult = $exceptionEvents.TalendDataCode
                    $this.InnerExceptionMessage = $exceptionEvents.Message
                }
            }
        }
    }
}


class PrtgSensorChannel {
    # Ref: https://www.paessler.com/manuals/prtg/custom_sensors#advanced_elements
    [ValidateNotNullOrEmpty()][string]$Name
    [string]$Value
    [string]$Unit
    [string]$CustomUnit
    [string]$SpeedSize
    [string]$VolumeSize
    [string]$SpeedTime
    [string]$Mode
    [string]$Float
    [string]$DecimalMode
    [string]$Warning
    [string]$ShowChart
    [string]$ShowTable
    [string]$LimitMaxError
    [string]$LimitMaxWarning
    [string]$LimitMinWarning
    [string]$LimitMinError
    [string]$LimitErrorMsg
    [string]$LimitWarningMsg
    [string]$LimitMode
    [string]$ValueLookup
    [string]$NotifyChanged


    # Constructors
    PrtgSensorChannel(
        [string]$name
    ){
        $this.Name = $name
    }

    # Public Methods
    [void]SetChannelLookup([string]$LookupId) {
        if ($LookupId.Length -eq 0) {
            throw "PRTG Sensor ValueLookup Id must not be empty or null."
        }
        $this.Unit = "Custom"
        $this.ValueLookup = $LookupId
    }

    [void]ClearChannelLookup() {
        $this.ValueLookup = ""
    }

    [string]GetChannelValue() {
        if ($null -ne $this.Value -and $this.Value -ne "") {
            return $this.Value
        }
        return $null
    }

    [void]SetChannelValue([string]$value) {
        if ($null -eq $value -or $value -eq "") {
            throw "Value must not be empty or null."
        }
        $this.Value = $value
    }

    [void]ClearChannelValue() {
        $this.Value = ""
    }

    [void]SetChannelParameter([string]$Name, [string]$Value) {
        $_class_properties = ($this |Get-Member -MemberType 'Property' |ForEach-Object {$_.Name})
        if ($null -eq $Name -or $Name -eq "" -or $Name -notin $_class_properties) {
            throw "Parameter not found or null or empty."
        }
        if ($null -eq $Value -or $Value -eq "") {
            throw "Parameter value null or empty."
        }
        $this.$Name = $Value
    }

    [void]SetChannelParameter([System.Collections.Hashtable]$Parameterlist) {
        $_class_properties = ($this |Get-Member -MemberType 'Property' |ForEach-Object {$_.Name})
        foreach ($param in $Parameterlist.Keys) {
            if ($param -notin $_class_properties) {
                throw "Parameter not found."
            }
            if ($null -eq $Parameterlist[$param] -or $Parameterlist[$param] -eq "") {
                throw "Parameter value null or empty."
            }
            $this.$param = $Parameterlist[$param]
        }
    }

    [string]GetChannelParameter([string]$Name) {
        $_class_properties = ($this |Get-Member -MemberType 'Property' |ForEach-Object {$_.Name})
        if ($null -eq $Name -or $Name -eq "" -or $Name -notin $_class_properties) {
            throw "Parameter not found or null or empty."
        }
        return $this.$Name
    }

    [void]WritePrtgXml() {
        $_class_properties = ($this |Get-Member -MemberType 'Property' |ForEach-Object {$_.Name})
        Write-Host("    <result>")
        Write-Host("        <Channel>{0}</Channel>" -f $this.Name)
        Write-Host("        <Value>{0}</Value>" -f $this.Value)
            foreach ($_property in $_class_properties) {
                if ($null -ne $this.$_property -and
                        $this.$_property -ne "" -and
                        $_property -notin @("Name", "Value")) {
                    Write-Host ("        <{0}>{1}</{0}>" -f $_property, $this.$_property)
                }
            }
        Write-Host("    </result>")
    }
}


class PrtgSensor {
    [ValidateNotNullOrEmpty()][string]$Name
    [ValidateNotNullOrEmpty()][PrtgSensorType]$Type
    [PrtgSensorChannel[]]$Channels
    [TalendLog]$TalendLog
    hidden [System.Collections.Hashtable]$ChannelsInternal
    hidden [Microsoft.Management.Infrastructure.CimInstance]$TaskMetricData
    hidden [Microsoft.Management.Infrastructure.CimInstance]$TaskMetricInfo


    # Constructors
    PrtgSensor (
        [string]$name
    ) {
        $this.Name = $name
        $this.Type = [PrtgSensorType]::Generic
        $this.ChannelsInternal = @{}
        $this.InitializeChannels([PrtgSensorType]::Generic)
    }

    PrtgSensor (
        [string]$name,
        [PrtgSensorType]$type
    ) {
        $this.Name = $name
        $this.Type = $type
        $this.ChannelsInternal = @{}
        $this.InitializeChannels($type)
    }

    # Public Methods
    [string]ToString() {
        $_class_string = "Class: [PrtgSensor]`r`n"
        if ($null -ne $this.TaskMetricData) {
            $_class_string += ("  TaskMetric: attached`r`n")
        }
        $_class_string += ("  Channels: {0}`r`n" -f $this.ChannelsInternal.Count)
        $_class_string += ("  Attr(Name): {0}`r`n" -f $this.Name)
        switch ($this.Type) {
            { $_ -band [PrtgSensorType]::Generic } { $_class_string += ("  Attr(Type): Generic`r`n") }
            { $_ -band [PrtgSensorType]::TalendScheduledTask } { $_class_string += ("  Attr(Type): TalendScheduledTask`r`n") }
        }
        return $_class_string
    }

    [void]SetTaskMetricData(
        [Microsoft.Management.Infrastructure.CimInstance]$ScheduledTask
    ) {
        $this.TaskMetricData = $ScheduledTask
        $this.TaskMetricInfo = Get-ScheduledTaskInfo $ScheduledTask
    }

    [Microsoft.Management.Infrastructure.CimInstance]GetTaskMetricData() {
        return $this.TaskMetricData
    }

    [void]SetTalendLog([TalendLog]$talendLog) {
        if ($null -eq $talendLog) {
            throw "TalendLog must not be empty or null."
        }
        $this.TalendLog = $talendLog
    }

    [TalendLog]GetTalendLog() {
        return $this.TalendLog
    }

    [void]MergeChannelData() {
        Write-Verbose ("Merge/Fuse Metric Data with Channel Properties...")
        $this.MergeScheduledTaskChannelData()
    }

    [PrtgSensorChannel]AddChannel([PrtgSensorChannel]$channel) {
        if (-not $this.ChannelsInternal.ContainsKey($channel.Name)) {
            if ($this.ChannelsInternal.Count -ge $this.Channels.Count) {
                throw "All Sensor Channels are already filled"
            }
    
            $this.Channels[$this.ChannelsInternal.Count] = $channel
            $this.ChannelsInternal[$channel.Name] = $channel
        }
        return $channel
    }

    [void]WritePrtgXml() {
        Write-Host ('<?xml version="1.0" encoding="UTF-8" ?>')
        Write-Host ("<prtg>")
        if ($this.ChannelsInternal.Count -eq 0) {
            Write-Host ("    <error>0</error>")
            Write-Host ("    <text>{0}</text>" -f "OK.")
        } else {
            $this.Channels |Where-Object {$null -ne $_ } |ForEach-Object {[PrtgSensorChannel]$_.WritePrtgXml()}

            # Default Sensor Text
            $_text = "OK. Task Name: {0} - Last Run: {1} - Next Run: {2}" -f
                $this.TaskMetricInfo.TaskName,
                (Get-Date $this.TaskMetricInfo.LastRunTime -UFormat "%Y-%m-%d %R"),
                (GEt-Date $this.TaskMetricInfo.NextRunTime -UFormat "%Y-%m-%d %R")

                # Sensor Text if type is TalendScheduledTask and Talend Job execution failed
            if ($this.Type -band [PrtgSensorType]::TalendScheduledTask -and
                    $this.TalendLog.GetLastRunResult() -ne 0) {
                $_text = "Task Name: {0} - Talend Error Code: {1} - Message,Stacktrace: {2} -- {3} - File: '{4}'" -f
                        $this.TaskMetricInfo.TaskName,
                        $this.TalendLog.GetLastRunResult(),
                        $this.TalendLog.GetInnerExceptionMessage(),
                        $this.TalendLog.GetStackTrace(),
                        $this.TalendLog.GetInnerExceptionLogFilename()
            }
            Write-Host ('    <text>{0}</text>' -f $_text)
        }
        Write-Host ('</prtg>')
    }

    # Private Methods
    hidden [void]InitializeChannels([PrtgSensorType]$type=[PrtgSensorType]::Generic) {
        Write-Verbose ("Initializing Sensor Channels...")
        $_channelCount = 0
        switch ($type) {
            { $_ -band [PrtgSensorType]::TalendScheduledTask} { $_channelCount = 4 }
            Default { $_channelCount = 3 }
        }
        # Reserve memory
        $this.Channels = [PrtgSensorChannel[]]::new($_channelCount)
        # Populate channels - kind of template
        # Channel Settings based on work of Markus Kraus
        #   (https://mycloudrevolution.com/de/2016/09/15/prtg-advanced-scheduled-task-sensor/)

        # Channel 1: Last Run In Hours
        [PrtgSensorChannel]$_channel = $this.AddChannel([PrtgSensorChannel]::new("Last Run"))
        $_channel.SetChannelParameter("Unit", "TimeHours")

        # Channel 2: Last Run Result
        [PrtgSensorChannel]$_channel = $this.AddChannel([PrtgSensorChannel]::new("Last Run Result"))
        $_channel.SetChannelParameter(@{
            "DecimalMode" = "All";
            "LimitMode" = "1";
            "LimitMinError" = "0";
            "LimitMaxError" = "0"
        })

        # Channel 3: State
        [PrtgSensorChannel]$_channel = $this.AddChannel([PrtgSensorChannel]::new("State"))
        $_channel.SetChannelLookup("prtg.standardlookups.disabledenabled.stateenabledok")

        # Talend Channels
        if ($this.Type -band [PrtgSensorType]::TalendScheduledTask) {
            # Channel 4: Talend Job Result
            [PrtgSensorChannel]$_channel = $this.AddChannel([PrtgSensorChannel]::new("Talend Job Result"))
            $_channel.SetChannelParameter(@{
                "DecimalMode" = "All";
                "LimitMode" = "1";
                "LimitMinError" = "0";
                "LimitMaxError" = "0"
            })
        }
    }

    hidden[void]MergeScheduledTaskChannelData() {
        # Channel 1: Last Run
        $_now = Get-Date
        $timespanSinceLastRun = New-TimeSpan -Start $this.TaskMetricInfo.LastRunTime -End $_now
        $hoursSinceLastRun = [math]::Round($timespanSinceLastRun.TotalHours, 2)
        if ($hoursSinceLastRun -ge 1) {
            $hoursSinceLastRun = [math]::Round($timespanSinceLastRun.TotalHours)
        }
        ([PrtgSensorChannel]$this.ChannelsInternal["Last Run"]).SetChannelValue($hoursSinceLastRun)

        # Channel 2: Last Run Result
        ([PrtgSensorChannel]$this.ChannelsInternal["Last Run Result"]).SetChannelValue($this.TaskMetricInfo.LastTaskResult)

        # Channel 3: State
        [string]$channelValue = "1"
        if ($this.TaskMetricData.State -eq 'Disabled' ) {
            $channelValue = "0"
        }
        ([PrtgSensorChannel]$this.ChannelsInternal["State"]).SetChannelValue($channelValue)

        # Talend Channels
        if ($this.Type -band [PrtgSensorType]::TalendScheduledTask) {
            # Channel 4: Talend Job Result
            ([PrtgSensorChannel]$this.ChannelsInternal["Talend Job Result"]).SetChannelValue(
                $this.TalendLog.GetLastRunResult())
        }
    }
}


class PrtgError {
    [int]$HResult
    [string]$Message
    [string]$StackTrace = ""


    # Constructors
    PrtgError($hresult, $message) {
        $this.HResult = $hresult
        $this.Message = $message
    }

    # Public Methods
    [void]WritePrtgXml() {

        # Sanetizing message: Replace CRLF with --, replace <> with []
        $_message = $this.Message -replace "`r`n", " -- " -replace "<", "[" -replace ">", "]"
        $_stacktrace = $this.StackTrace  -replace "`r`n", " -- " -replace "<", "[" -replace ">", "]"
        Write-Host ('<?xml version="1.0" encoding="UTF-8" ?>')
        Write-Host ("<prtg>")
        Write-Host ("    <error>{0}</error>" -f $this.HResult)
        Write-Host ("    <text>{0}</text>" -f (@($_message, $_stackTrace) -join " .. "))
        Write-Host ('</prtg>')
    }
}


class PrtgOk {
    static [void]WritePrtgXml($message) {
        $_message = $message -replace "`r`n", " -- " -replace "<", "[" -replace ">", "]"
        Write-Host ('<?xml version="1.0" encoding="UTF-8" ?>')
        Write-Host ("<prtg>")
        Write-Host ("    <error>0</error>")
        Write-Host ("    <text>{0}</text>" -f $_message)
        Write-Host ('</prtg>')

    }
}
#endregion Classes

# Show Version
if ($Version) {
    Write-Host ("")
    Write-Host ("$_SCRIPTNAME")
    Write-Host ("--")
    Write-Host ("Author: $_AUTHOR")
    Write-Host ("Version: $_VERSION")
    Write-Host ("")
    exit 0
}
# Run Main
. Main
