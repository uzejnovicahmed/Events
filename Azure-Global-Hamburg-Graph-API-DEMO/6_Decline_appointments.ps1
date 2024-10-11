#Calendars.ReadBasic, Calendars.Read, Calendars.ReadWrite


Set-Secret -Name "Decline Appointments" -Secret ""
Get-Secret -Name "Decline Appointments"  -AsPlainText

#f4545efd
$clientid = ""
$secret = Get-Secret -Name "Decline Appointments"  -AsPlainText
$tenantname = ""
$tenantid = ""
$UPN = ""
#alexw

function Request-AccessToken {

    [CmdletBinding()]
    param (
        # The Microsoft Azure AD Tenant Name
        [Parameter(ParameterSetName = 'ClientAuth', Mandatory = $true)]  [string]$TenantName,
        # The Microsoft Azure AD TenantId (GUID or domain)
        [Parameter(ParameterSetName = 'ClientAuth', Mandatory = $true)]  [string]$ClientId,
        # An authentication secret of the Microsoft Azure AD Application Registration
        [Parameter(ParameterSetName = 'ClientAuth', Mandatory = $true)] [string]$ClientSecret
    )
      
    $resource = "https://graph.microsoft.com/"  
    
    $tokenBody = @{  
        Grant_Type    = 'client_credentials'  
        Scope         = 'https://graph.microsoft.com/.default'  
        Client_Id     = $ClientId  
        Client_Secret = $clientSecret  
    }  
    
    try { $tokenResponse = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$TenantName/oauth2/v2.0/token" -Method POST -Body $tokenBody -ErrorAction Stop }catch { return "Error generating access token $($_)" }
    Write-Debug "Successfully generated authentication token"
    return $($tokenResponse.access_token)
}

function Get-AzureResourcePaging {
    param (
        $URL,
        $AuthHeader
    )
 
    # List Get all Apps from Azure

    $Response = Invoke-RestMethod -Method GET -Uri $URL -Headers $AuthHeader
    $Resources = $Response.value

    $ResponseNextLink = $Response."@odata.nextLink"
    while ($ResponseNextLink -ne $null) {

        $Response = (Invoke-RestMethod -Uri $ResponseNextLink -Headers $AuthHeader -Method Get)
        $ResponseNextLink = $Response."@odata.nextLink"
        $Resources += $Response.value
    }
    return $Resources
}

$token = Request-AccessToken -TenantName $tenantname -ClientId $clientid -ClientSecret $secret


try{

$headers = @{
    "Authorization" = "Bearer $($token)"
    "Content-type"  = "application/json;charset=utf-8"
}


$URL = "https://graph.microsoft.com/v1.0/users/$($UPN)/calendar/events"

$Events = Get-AzureResourcePaging -URL $URL -AuthHeader $headers
$Events = $Events | where-object {$_.isCancelled -eq $false}
$Events = $Events | where {(Get-Date $_.start.dateTime) -gt (Get-Date)}

foreach ($event in $Events) {

    
    if ($($event.organizer.emailAddress.address) -eq $UPN) {
        
        $body = @{

            "comment" = "Dieser Termin wurde automatisch abgesagt, da der Mitarbeiter ##Nachname ##Vorname nicht mehr im unserem Unternehmen tätig ist. Wir bitten um Ihr Verständnis"
        } | ConvertTo-Json

        $URL = "https://graph.microsoft.com/v1.0/users/$($UPN)/calendar/events/$($event.id)/cancel"
    
    }
    else {
       
$Organizer = $event.organizer.emailAddress.address
    
        if($Organizer -like "*hamburg.com") {
            
            $body = @{
             "sendResponse" = $false
            } | ConvertTo-Json
        }
        else
        {
            $body = @{
                "comment" = "Hallo $($event.organizer.emailAddress.name), dieser Termin wurde automatisch abgesagt, da der Mitarbeiter nicht mehr im unserem Unternehmen tätig ist. Wir bitten um Ihr Verständnis"
                "sendResponse" = $true
            } | ConvertTo-Json
        }

    
        $URL = "https://graph.microsoft.com/v1.0/users/$($UPN)/calendar/events/$($event.id)/decline"
    
    }


$bodybytes = [System.Text.Encoding]::UTF8.GetBytes($body)

    Invoke-RestMethod -Method POST -Uri $URL -Body $bodybytes -Headers $headers

}

$status = "Success"

}
catch{
    $Status = "failed"
    Throw "Error: $($_)"
}


$status