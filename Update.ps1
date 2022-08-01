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
    if (Confirm-AccessTokenIsValid -eq $true) {       
        return
    }

    $url = "https://api.raet.com/authentication/token"
    $authorisationBody = @{
        'grant_type'    = "client_credentials"
        'client_id'     = $ClientId
        'client_secret' = $ClientSecret
    } 
    try {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
        $result = Invoke-WebRequest -Uri $url -Method Post -Body $authorisationBody -ContentType 'application/x-www-form-urlencoded' -Headers @{'Cache-Control' = "no-cache" } -Proxy:$Proxy -UseBasicParsing
        $accessToken = $result.Content | ConvertFrom-Json
        $Script:expirationTimeAccessToken = (Get-Date).AddSeconds($accessToken.expires_in)

        $Script:AuthenticationHeaders = @{
            'X-Client-Id'      = $ClientId;
            'Authorization'    = "Bearer $($accessToken.access_token)";
            'X-Raet-Tenant-Id' = $TenantId;
        }     
        

    } catch {
        if ($_.Exception.Response.StatusCode -eq "Forbidden") {
            $errorMessage = "Something went wrong $($_.ScriptStackTrace). Error message: '$($_.Exception.Message)'"
        } elseif (![string]::IsNullOrEmpty($_.ErrorDetails.Message)) {
            $errorMessage = "Something went wrong $($_.ScriptStackTrace). Error message: '$($_.ErrorDetails.Message)'" 
        } else {
            $errorMessage = "Something went wrong $($_.ScriptStackTrace). Error message: '$($_)'" 
        }  
        throw $errorMessage
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


if ($account.mail -ne $p.contact.business.email) {

    if(-Not($dryRun -eq $True)) {
        #Export DPIA100
        Try{
            new-RaetSession -ClientId $clientId -ClientSecret $clientSecret -TenantId $tenantID
            $PostURL = 'https://api.raet.com/mft/v1.0/files?uploadType=multipart'
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

            #$result = Invoke-WebRequest -Uri $PostURL -Method 'POST' -ContentType "multipart/related;boundary=$boundary" -Headers $Script:AuthenticationHeaders -Body $bodyLines

            $success = $True
            $auditMessage = "for person " + $p.DisplayName + " DPIA100 successfully exported"
        }
        Catch{
            $auditMessage = "for person " + $p.DisplayName + " DPIA100 failed to export $_"
        }
    } else {
        Write-Verbose -Verbose "Dry mode: $output"
    }

} else {
    $success = $True
    $auditMessage = "for person " + $p.DisplayName + ": DPIA100 update not required."
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
