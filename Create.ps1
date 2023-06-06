#Initialize default properties
$p = $person | ConvertFrom-Json
$success = $False;
$auditMessage = "for person " + $p.DisplayName
$config = $configuration | ConvertFrom-Json

#Supportive Functions:
$clientId = $config.clientid
$clientSecret = $config.clientsecret
$TenantId = $config.tenantid

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls

$Script:AuthenticationUri = "https://connect.visma.com/connect/token"
$Script:BaseUri = "https://fileapi.youforce.com/"

#region functions
function Resolve-HTTPError {
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

function Get-ErrorMessage {
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

function New-RaetSession {
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
    $accessTokenValid = Confirm-AccessTokenIsValid
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

        Write-Verbose "Creating Access Token at uri '$($splatAccessTokenParams.Uri)'"

        $result = Invoke-RestMethod @splatAccessTokenParams -Verbose:$false
        if ($null -eq $result.access_token) {
            throw $result
        }

        $Script:expirationTimeAccessToken = (Get-Date).AddSeconds($result.expires_in)

        $Script:AuthenticationHeaders = @{
            'Authorization' = "Bearer $($result.access_token)"
            'Accept'        = "application/json"
        }

        Write-Verbose "Successfully created Access Token at uri '$($splatAccessTokenParams.Uri)'"
    }
    catch {
        $ex = $PSItem
        $errorMessage = Get-ErrorMessage -ErrorObject $ex

        Write-Verbose "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($($errorMessage.VerboseErrorMessage))"

        $auditLogs.Add([PSCustomObject]@{
                # Action  = "" # Optional
                Message = "Error creating Access Token at uri ''$($splatAccessTokenParams.Uri)'. Please check credentials. Error Message: $($errorMessage.AuditErrorMessage)"
                IsError = $true
            })     
    }
}

function Confirm-AccessTokenIsValid {
    if ($null -ne $Script:expirationTimeAccessToken) {
        if ((Get-Date) -le $Script:expirationTimeAccessToken) {
            return $true
        }
    }
    return $false
}
#endregion functions

#Change mapping here
$account = [PSCustomObject]@{
    externalId = $p.externalid
    mail = $p.accounts.MicrosoftActiveDirectory.mail
}

#Default variables for export
$user = $config.dpia100.creatiegebruiker
$prefix = $config.dpia100.fileprefix
$stam = $config.dpia100.stam
$suffix = Get-Date -Format ddMMyyy
$filename = $prefix + $suffix + '-'+ $($account.externalID) + ".txt"
$currentDate = Get-Date -Format ddMMyyyy
$productionTypeDate = Get-Date -Format MMyyyy


#Building fixed length fields
$processcode = "IMP $(" " * 3)".Substring(0,3)
$indication= "$stam $(" " * 1)".Substring(0,1) # V for Variable S for Stam
$exportDate = "$currentDate $(" " * 11)".Substring(0,11)
$startDate = "$currentDate $(" " * 11)".Substring(0,11)
$creationUser = "$user $(" " * 16)".Substring(0,16)
$productionType = "NOR$productionTypeDate $(" " * 9)".Substring(0,9)
$spaces = "$(" " * 30)".Substring(0,30)

#Input Variables from HelloID
$objectId = "$($account.externalId) $(" " * 50)".Substring(0,50)
$rubrieksCode = "P01035 $(" " * 6)".Substring(0,6)
$value = "$($account.mail) $(" " * 50)".Substring(0,50)

$output = "$processcode" + "$rubriekscode" + "$objectId" + "$indication" + "$exportDate" + "$creationUser" + "$value" + "$startDate" + "$spaces" + "$productionType"

if(-Not($dryRun -eq $True)) {
    #Export DPIA100
    Try{
        New-RaetSession -ClientId $clientId -ClientSecret $clientSecret -TenantId $tenantId
        $PostURL = "$($Script:BaseUri)/v1.0/files?uploadType=multipart"
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

        $result = Invoke-WebRequest -Uri $PostURL -Method 'POST' -ContentType "multipart/related;boundary=$boundary" -Headers $Script:AuthenticationHeaders -Body $bodyLines

        $success = $True
        $auditMessage = "for person " + $p.DisplayName + " DPIA100 successfully exported"
    }
    Catch{
        $auditMessage = "for person " + $p.DisplayName + " DPIA100 failed to export $_"
    }
} else {
    Write-Verbose -Verbose "Dry mode: $output"
}

#build up result
$result = [PSCustomObject]@{ 
	Success = $success
	AccountReference = $account.externalId
	AuditDetails = $auditMessage
    Account = $account
};

#send result back
Write-Output $result | ConvertTo-Json -Depth 10