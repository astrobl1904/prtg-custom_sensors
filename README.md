# prtg-exescriptadvanced-TalendScheduledTask

This project contains source code of the PRTG EXE/Script Advanced sensor `Get-TalendScheduledTask`.

## Sensor Summary

    Script Language: Powershell
    Version: v1.0.0
    Author: Andreas Strobl <astroblx@asgraphics.at>

* Docs Sensor: [Custom Sensors/EXEXML/docs/Get-TalendScheduledTask_ps1.md](https://github.com/astrobl1904/prtg-exescriptadvanced-TalendScheduledTask/blob/main/Custom%20Sensors/EXEXML/docs/Get-TalendScheduledTask_ps1.md)
* Docs Classes: [Custom Sensors/EXEXML/docs/Class_Definitions.md](https://github.com/astrobl1904/prtg-exescriptadvanced-TalendScheduledTask/blob/main/Custom%20Sensors/EXEXML/docs/Class_Definitions.md)

## Sensor Description

This Advanced Sensor will report Task statistics based on Windows Scheduled Task and
error entries it found in a XML log file maintained by the Talend orchestration job.

This script performs two tests: it checks for the periodic execution of the defined
Windows Scheduled Task and looks for error entries in the Talend Job maintained log file.

Additionally this Advanced Sensor script allows to monitor whether the Windows task is
disabled. In this case an error will be reported back to the probe.

## Parameters

**ComputerName** `string`, `mandatory`:
    Specifies the computer on which the command runs. The default is the local computer.

**SensorName**, `string`, `mandatory`:
    Specifies the name of the PRTG sensor.

**TaskName**, `string`, `mandatory`:
    Specifies a name of a scheduled task for Talend Open Studio.

**TaskPath**, `string`, `optional`:
    Specifies a path for scheduled tasks in Task Scheduler namespace. You can use `/` for the root folder. If you do not specify a path, the cmdlet uses the root folder. Since _PRTG_ posseses limited parsing capabilities the path separator MUST BE `/`.

**WindowsUser**, `string`, `optional`:
    Specifies the username that authenticates the PSSession. If required pass
    on PRTG parameter `%windowsuser`.

**WindowsPassword**, `secureString`, `optional`:
    Specifies the password to authenticate the PSSession. If required pass on PRTG
    parameter %windowspassword. Do not provide this value on the commandline
    use `-WindowsCredential` instead.

**WindowsCredential**, `PSCredential`, `optional`:
    Specifies a PSCredential object to authenticate the PSSession.

**TalendLogFile**, `literalPath`, `optional`:
    Specifies an absolute literal path to a file a Talend Job logs its START-END events to. Use `/` as path separator.

**TalendJobNamespace**, `string`, `optional`:
    Specifies the namespace in domain reverse order. Required if handling _Talend Open Studio_ log files.
