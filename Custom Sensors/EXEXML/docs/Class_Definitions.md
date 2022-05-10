# Class Definitions

This implementation contains multiple classes to handle PRTG sensor results. It is comparable to Paessler's own implementation with _Python_ sensors.

## Enum PrtgSensorType

`PrtgSensorType` is used to create the supported channels when ceating a new sensor object.

* `Generic`: 1
* `TalendScheduledTask`: 2

## Class TalendLog

Class TalendLog contains all the handling of the primary Talend Job log and an optional exception log created by a subjob triggered with component `tLogCatcher`.

The class is instantiated with the content of the primary orchestration log and the namespace of the Talend orchestration job (in reverse dotted notation; e.g. **`com.example.talend.projectid.jobid`**).

The Talend subjob providing the attributes for the XML dump writes the namespace parted as leaf and parent in multiple child nodes within node `<Event>`. You will find the source code of the _Talend_ subjob and the generic schema used to create the log file in the _support_ directory.

### TalendLog Constructor

* **`TalendLog`**(`[string]` **`$content`**, `[string]` **`$namespace`**)

### TalendLog Properties

* `[xml]` **`$Content`**
* `[xml]` **`$InnerException`**

### TalendLog Methods

* `[bool]` **`InnerExceptionLoaded`**()
* `[bool]` **`InnerExceptionRequired`**()
* `[void]` **`ImportInnerException`**(`[string[]]` **`$content`**)
* `[int]` **`GetLastRunResult`**()
* `[void]` **`ConfirmLastRunResult`**()
* `[string]` **`GetInnerExceptionLogFilename`**()
* `[string]` **`GetStackTrace`**()
* `[string]` **`GetInnerExceptionMessage`**()
* `[int]` **`GetInnerExceptionCode`**()

## Class PrtgSensorChannel

### PrtgSensorChannel Constructor

* **`PrtgSensorChannel`**(`[string]` **`$name`**)

### PrtgSensorChannel Properties

* `[string]` **`$Name`**
* `[string]` **`$Value`**
* `[string]` **`$Unit`**
* `[string]` **`$CustomUnit`**
* `[string]` **`$SpeedSize`**
* `[string]` **`$VolumeSize`**
* `[string]` **`$SpeedTime`**
* `[string]` **`$Mode`**
* `[string]` **`$Float`**
* `[string]` **`$DecimalMode`**
* `[string]` **`$Warning`**
* `[string]` **`$ShowChart`**
* `[string]` **`$ShowTable`**
* `[string]` **`$LimitMaxError`**
* `[string]` **`$LimitMaxWarning`**
* `[string]` **`$LimitMinWarning`**
* `[string]` **`$LimitMinError`**
* `[string]` **`$LimitErrorMsg`**
* `[string]` **`$LimitWarningMsg`**
* `[string]` **`$LimitMode`**
* `[string]` **`$ValueLookup`**
* `[string]` **`$NotifyChanged`**

### PrtgSensorChannel Methods

* `[void]` **`SetChannelLookup`**(`[string]` **`$LookupId`**)
* `[void]` **`ClearChannelLookup`**()
* `[string]` GetChannelValue()
* `[void]` **`SetChannelValue`**(`[string]` **`$value`**)
* `[void]` **`ClearChannelValue`**()
* `[void]` **`SetChannelParameter`**(`[string]` **`$Name`**, `[string]` **`$Value`**)
* `[void]` **`SetChannelParameter`**(`[System.Collections.Hashtable]` **`$Parameterlist`**)
* `[string]` **`GetChannelParameter`**(`[string]` **`$Name`**)
* `[void]` **`WritePrtgXml`**()

## Class PrtgSensor

### PrtgSensor Constructor

* **`PrtgSensor`**(`[string]` **`$name`**)
* **`PrtgSensor`**(`[string]` **`$name`**, `[PrtgSensorType]` **`$type`**)

### PrtgSensor Properties

* `[string]` **`$Name`**
* `[PrtgSensorType]` **`$Type`**
* `[PrtgSensorChannel[]]` **`$Channels`**
* `[TalendLog]` **`$TalendLog`**

### PrtgSensor Methods

* `[string]` **`ToString`**()
* `[void]` **`SetTaskMetricData`**(`[Microsoft.Management.Infrastructure.CimInstance]` **`$ScheduledTask`**)
* `[Microsoft.Management.Infrastructure.CimInstance]` **`GetTaskMetricData`**()
* `[void]` **`SetTalendLog`**(`[TalendLog]` **`$talendLog`**)
* `[TalendLog]` **`GetTalendLog`**()
* `[void]` **`MergeChannelData`**()
* `[PrtgSensorChannel]` **`AddChannel`**(`[PrtgSensorChannel]` **`$channel`**)
* `[void]` **`WritePrtgXml`**()

## Class PrtgError

### PrtgError Constructor

* **`PrtgError`**(`[int]` **`$hresult`**, `[string]` **`$message`**)

### PrtgError Properties

* `[int]` **`$HResult`**
* `[string]` **`$Message`**
* `[string]` **`$StackTrace`**

### PrtgError Methods

* `[void]` **`WritePrtgXml`**()

## Class PrtgOK

Simple class to write a PRTG OK message string.

### PrtgOK Static Methods

* `[void]` **`WritePrtgXml`**(`[string]` **`$message`**)
