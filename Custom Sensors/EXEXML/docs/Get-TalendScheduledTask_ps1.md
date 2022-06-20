# Get-TalendScheduledTask

PRTG Advanced Scheduled Task Sensor for Talend Open Studio ETL Jobs and Log files.

## Description

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
\<text\> element.
 
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

## Notes on PRTG Parsing

PRTG has limited parameter parsing capabilities. This has immediate effects on how to enter paths in the sensor definition. Escaping with backslash only works in conjunction with quotes but not with the backslash itself. In all path paramters (TaskPath, LogFile) the forward slash has to be used. In the sensor script this will be replaced with backslash as required.

## Notes on Windows Remoting

This script creates two sessions to the remote computer - one `CimSession` to query the remote's task scheduler service, and one `PSSession` for logfile handling. This implementation currently uses WSMAN via _HTTPS_ and requires a valid certificate installed on the remote computer to succeed. Future _Windows Server_ versions might also support _SSH_ to be used to connect to remote computers.

## Notes on Logfile Handling over WSMAN

The logfile is copied from the remote to the PRTG probe. Avoid logfiles to grow beyond 0.5M since the download takes some time. To prevent the sensor to stall increase the timeout from 60sec to 180sec.

## Links

* PRTG Manual - Custom Sensors: <https://www.paessler.com/manuals/prtg/custom_sensors#advanced_sensors>
* PRTG Manual - Custom Sensor, Advanced Elements: <https://www.paessler.com/manuals/prtg/custom_sensors#advanced_elements>
* Markus Kraus - MY CLOUD (R)EVOLUTION: <https://mycloudrevolution.com/de/2016/09/15/prtg-advanced-scheduled-task-sensor/>
