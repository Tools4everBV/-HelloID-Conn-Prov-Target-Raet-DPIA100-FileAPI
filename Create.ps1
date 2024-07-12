#################################################
# HelloID-Conn-Prov-Target-RAET-FileAPI-DPIA100-Create
# PowerShell V2
#################################################

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

$Script:AuthenticationUri = "https://connect.visma.com/connect/token"
$Script:BaseUri = "https://fileapi.youforce.com/"

#region functions

function Resolve-RAET-FileAPI-DPIA100-HTTPError {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,
            ValueFromPipeline
        )]
        [object]$ErrorObject
    )
    process {
        $httpErrorObj = [PSCustomObject]@{
            FullyQualifiedErrorId = $ErrorObject.FullyQualifiedErrorId
            MyCommand             = $ErrorObject.InvocationInfo.MyCommand
            RequestUri            = $ErrorObject.TargetObject.RequestUri
            ScriptStackTrace      = $ErrorObject.ScriptStackTrace
            ErrorMessage          = ''
        }
        if ($ErrorObject.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') {
            $httpErrorObj.ErrorMessage = $ErrorObject.ErrorDetails.Message
        }
        elseif ($ErrorObject.Exception.GetType().FullName -eq 'System.Net.WebException') {
            $httpErrorObj.ErrorMessage = [System.IO.StreamReader]::new($ErrorObject.Exception.Response.GetResponseStream()).ReadToEnd()
        }
        Write-Output $httpErrorObj
    }
}

function Get-RAET-FileAPI-DPIA100-ErrorMessage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,
            ValueFromPipeline
        )]
        [object]$ErrorObject
    )
    process {
        $errorMessage = [PSCustomObject]@{
            VerboseErrorMessage = $null
            AuditErrorMessage   = $null
        }

        if ( $($ErrorObject.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or $($ErrorObject.Exception.GetType().FullName -eq 'System.Net.WebException')) {
            $httpErrorObject = Resolve-HTTPError -Error $ErrorObject

            $errorMessage.VerboseErrorMessage = $httpErrorObject.ErrorMessage

            $errorMessage.AuditErrorMessage = $httpErrorObject.ErrorMessage
        }

        # If error message empty, fall back on $ex.Exception.Message
        if ([String]::IsNullOrEmpty($errorMessage.VerboseErrorMessage)) {
            $errorMessage.VerboseErrorMessage = $ErrorObject.Exception.Message
        }
        if ([String]::IsNullOrEmpty($errorMessage.AuditErrorMessage)) {
            $errorMessage.AuditErrorMessage = $ErrorObject.Exception.Message
        }

        Write-Output $errorMessage
    }
}

function New-RAET-FileAPI-DPIA100-Session {
    [CmdletBinding()]
    param (
        [Alias("Param1")] 
        [parameter(Mandatory = $true)]  
        [string]      
        $ClientId,

        [Alias("Param2")] 
        [parameter(Mandatory = $true)]  
        [string]
        $ClientSecret,

        [Alias("Param3")] 
        [parameter(Mandatory = $false)]  
        [string]
        $TenantId
    )

    #Check if the current token is still valid
    $accessTokenValid = Confirm-RAET-FileAPI-DPIA100-AccessTokenIsValid
    if ($true -eq $accessTokenValid) {
        return
    }

    try {
        # Set TLS to accept TLS, TLS 1.1 and TLS 1.2
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12

        $authorisationBody = @{
            'grant_type'    = "client_credentials"
            'client_id'     = $ClientId
            'client_secret' = $ClientSecret
            'tenant_id'     = $TenantId
        }        
        $splatAccessTokenParams = @{
            Uri             = $Script:AuthenticationUri
            Headers         = @{'Cache-Control' = "no-cache" }
            Method          = 'POST'
            ContentType     = "application/x-www-form-urlencoded"
            Body            = $authorisationBody
            UseBasicParsing = $true
        }

        Write-Information "Creating Access Token at uri '$($splatAccessTokenParams.Uri)'"

        $result = Invoke-RestMethod @splatAccessTokenParams -Verbose:$false
        if ($null -eq $result.access_token) {
            throw $result
        }

        $Script:expirationTimeAccessToken = (Get-Date).AddSeconds($result.expires_in)

        $Script:AuthenticationHeaders = @{
            'Authorization' = "Bearer $($result.access_token)"
            'Accept'        = "application/json"
        }

        Write-Information "Successfully created Access Token at uri '$($splatAccessTokenParams.Uri)'"
    }
    catch {
        $ex = $PSItem
        $errorMessage = Get-RAET-FileAPI-DPIA100-ErrorMessage -ErrorObject $ex

        Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($($errorMessage.VerboseErrorMessage))"

        $auditLogs.Add([PSCustomObject]@{
                # Action  = "" # Optional
                Message = "Error creating Access Token at uri ''$($splatAccessTokenParams.Uri)'. Please check credentials. Error Message: $($errorMessage.AuditErrorMessage)"
                IsError = $true
            })     
    }
}

function Confirm-RAET-FileAPI-DPIA100-AccessTokenIsValid {
    if ($null -ne $Script:expirationTimeAccessToken) {
        if ((Get-Date) -le $Script:expirationTimeAccessToken) {
            return $true
        }
    }
    return $false
}
#endregion

try {
    # Initial Assignments
    $outputContext.AccountReference = 'Currently not available'

    # Validate correlation configuration
    if ($actionContext.CorrelationConfiguration.Enabled) {
        $correlationField = $actionContext.CorrelationConfiguration.accountField
        $correlationValue = $actionContext.CorrelationConfiguration.accountFieldValue

        if ([string]::IsNullOrEmpty($($correlationField))) {
            throw 'Correlation is enabled but not configured correctly'
        }
        if ([string]::IsNullOrEmpty($($correlationValue))) {
            throw 'Correlation is enabled but [accountFieldValue] is empty. Please make sure it is correctly mapped'
        }
    }

    #Default variables for export
    $user = $actionContext.Configuration.dpia100.creatiegebruiker
    $prefix = $actionContext.Configuration.dpia100.fileprefix
    $stam = $actionContext.Configuration.dpia100.stam
    $suffix = Get-Date -Format ddMMyyy
    $filename = $prefix + $suffix + '-' + $($actionContext.Data.externalID) + ".txt"
    $currentDate = Get-Date -Format ddMMyyyy
    $productionTypeDate = Get-Date -Format MMyyyy

    #Building fixed length fields
    $processcode = "IMP $(" " * 3)".Substring(0, 3)
    $indication = "$stam $(" " * 1)".Substring(0, 1) # V for Variable S for Stam
    $exportDate = "$currentDate $(" " * 11)".Substring(0, 11)
    $startDate = "$currentDate $(" " * 11)".Substring(0, 11)
    $creationUser = "$user $(" " * 16)".Substring(0, 16)
    $productionType = "NOR$productionTypeDate $(" " * 9)".Substring(0, 9)
    $spaces = "$(" " * 30)".Substring(0, 30)

    #Input Variables from HelloID
    $objectId = "$($actionContext.Datat.externalId) $(" " * 50)".Substring(0, 50)
    $rubrieksCode = "P01035 $(" " * 6)".Substring(0, 6)
    $value = "$($actionContext.Data.mail) $(" " * 50)".Substring(0, 50)

    $output = "$processcode" + "$rubriekscode" + "$objectId" + "$indication" + "$exportDate" + "$creationUser" + "$value" + "$startDate" + "$spaces" + "$productionType"


    # Add a message and the result of each of the validations showing what will happen during enforcement
    if ($actionContext.DryRun -eq $true) {
        Write-Information "[DryRun] RAET-FileAPI-DPIA100 export [$output] for account [$($personContext.Person.DisplayName)] will be executed during enforcement"
    }

    # Process
    if (-not($actionContext.DryRun -eq $true)) {
        Write-Information "Exporting [$output] RAET-FileAPI-DPIA100 for account [$($personContext.Person.DisplayName)]"

        try {
            New-RAET-FileAPI-DPIA100-Session -ClientId $actionContext.Configuration.clientId -ClientSecret $actionContext.Configuration.clientSecret -TenantId $actionContext.Configuration.tenantId

            $boundary = "foo_bar_baz"
            $LF = "`r`n"
            $bodyLines = (
                "--$boundary",
                "Content-Type: application/json; charset=UTF-8$LF",
                "{",
                "`"name`":`"$filename`",",
                "`"businesstypeid`":`"101020`"",
                "}$LF",
                "--$boundary$LF",
                "$output",
                "--$boundary--"
            ) -join $LF

            $splatUpdateParams = @{
                Uri         = "$($Script:BaseUri)/v1.0/files?uploadType=multipart"
                Headers     = $Script:AuthenticationHeaders
                Method      = 'POST'
                ContentType = "multipart/related;boundary=$boundary"
                Body        = $bodyLines
                
            }

            $result = Invoke-WebRequest @splatUpdateParams

            $outputContext.Data = $actionContext.Data
            $outputContext.AccountReference = $actionContext.Data.externalId
    
            $auditLogMessage = "Export [$output] RAET-FileAPI-DPIA100 was successful. AccountReference is: [$($outputContext.AccountReference)]"
            
            $outputContext.AccountCorrelated = $false
            $outputContext.success = $true
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Action  = "CreateAccount"
                    Message = $auditLogMessage
                    IsError = $false
                })
        }
        catch {
            $auditLogMessage = "Export [$output] RAET-FileAPI-DPIA100 failed. Error: $_.Exception.Message"
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Action  = "CreateAccount"
                    Message = $auditLogMessage
                    IsError = $true
                })
        }
        
    }
}
catch {
    $outputContext.success = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-RAET-FileAPI-DPIA100-HTTPError -ErrorObject $ex
        $auditMessage = "Could not export RAET-FileAPI-DPIA100 for account [$($personContext.Person.DisplayName)]. Error: $($errorObj.FriendlyMessage)"
        Write-Warning "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    }
    else {
        $auditMessage = "Could not export RAET-FileAPI-DPIA100 account [$($personContext.Person.DisplayName)]. Error: $($ex.Exception.Message)"
        Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = $auditMessage
            IsError = $true
        })
}
