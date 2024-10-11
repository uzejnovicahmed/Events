### Mastering Microsoft Graph API Pagination


#region Authentication
$ClientID = ""
$tenantid = ""
$clientsecret = Get-Secret -Name "Azure Global Hamburg Secret"  -AsPlainText
#Authentication
#Connect to GRAPH API

$token_Body = @{
    Grant_Type    = "client_credentials"
    Scope         = "https://graph.microsoft.com/.default"
    Client_Id     = $clientId
    Client_Secret = $clientSecret
}

$token_Response = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$tenantID/oauth2/v2.0/token" -Method POST -Body $token_Body

$token_Header = @{
    "Authorization" = "Bearer $($token_Response.access_token)"
    "Content-type"  = "application/json"
    "consistencyLevel" = "eventual" #Had to be added for advanced querys
}

#endregion

#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#








#region Pagination


$URI = "https://graph.microsoft.com/v1.0/users"
$users = Invoke-RestMethod -Method Get -Uri $URI -Headers $token_Header


$nexurl = $users.'@odata.nextLink'

$usersnexturl = Invoke-RestMethod -Method Get -Uri $nexurl -Headers $token_Header

$usersnexturl.value.count


#endregion Pagination

#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#










#region Pagina  with function
function Get-AzureResourcePaging{
    
    param(
        $URL,
        $AuthHeader
    )

    $Response = Invoke-RestMethod -Method GET -Uri $URL -Headers $AuthHeader
    $Resources = $Response.value

    $ResponseNextLink = $Response."@odata.nextLink"

        while ($ResponseNextLink -ne $null) {

            $Response = (Invoke-RestMethod -Uri $ResponseNextLink -Headers $AuthHeader -Method Get)
            $ResponseNextLink = $Response."@odata.nextLink"
            $Resources += $Response.value
        }

        if ($null -eq $Resources) {  #sometimes the response contains directly data and not a value object. for expample when you query for a single user
            $Resources = $Response
        }
    
    return $Resources

    }



$allusers = Get-AzureResourcePaging -URL "https://graph.microsoft.com/v1.0/users" -AuthHeader $token_Header


$allusers.count


#endregion

#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#









