### Mastering Microsoft Graph API Advanced Querys

#https://learn.microsoft.com/en-us/graph/aad-advanced-queries?tabs=http

#region secret vault 
#use secret vault from PowerShell here !  https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.secretmanagement/?view=ps-modules
Install-Module Microsoft.PowerShell.SecretManagement -Force -AllowClobber
Import-Module Microsoft.PowerShell.SecretManagement

Set-Secret -Name "Azure Global Hamburg Secret" -Secret "" 

$clientsecret = Get-Secret -Name "Azure Global Hamburg Secret"  -AsPlainText

#endregion

#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#

#region Authentication
$ClientID = ""
$tenantid = ""

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

}

$token_Header_eventual = @{
    "Authorization" = "Bearer $($token_Response.access_token)"
    "Content-type"  = "application/json"
    "consistencyLevel" = "eventual" #Had to be added for advanced querys
}

#endregion

#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#

#region Get all disabled users in the Entra ID tenant 

$users = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/users?`$filter=accountEnabled eq false" -Headers $token_Header

$users = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/users?`$filter=accountEnabled ne true" -Headers $token_Header

$users = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/users?`$filter=accountEnabled ne true&`$count=true" -Headers $token_Header

$users.value.displayName

#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#


#encoding bei Sonderzeichen

$department = "thisis=+atest"
$escapeddepartment = [System.Uri]::EscapeDataString($department)

$filterurl = "https://graph.microsoft.com/v1.0/users?`$filter=department eq '$($department)'&`$select=department,userprincipalname,id,Mail,givenname"
$filterurl = "https://graph.microsoft.com/v1.0/users?`$filter=department eq '$($escapeddepartment)'&`$select=department,userprincipalname,id,Mail,givenname"

$user = Invoke-RestMethod -Uri $filterurl -Headers $token_Header_eventual



#endregion


#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#


#endregion

#Test OneWaySync

# User ID and new display name
$userId = "48d39ccd-2715-450f-9355-f5c93d44e92e"
$newDisplayName = "Alexander Brown"

# User update body
$userUpdateBody = @{
    displayName = $newDisplayName
} | ConvertTo-Json

# User update URI
$URI = "https://graph.microsoft.com/v1.0/users/$userId"

# Send the PATCH request
Invoke-RestMethod -Method Patch -Uri $URI -Headers $token_Header -Body $userUpdateBody

$user = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/users?`$filter=ID eq '$($userid)'" -Headers $token_Header
$user.value

$user = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/users?`$filter=ID eq '$($userId)'&`$count=true" -Headers $token_Header_eventual
$user.value


#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#






#region signle operators

# equals to
$URI = "https://graph.microsoft.com/v1.0/users?`$filter=displayName eq 'Alex Wilber'"
$result = Invoke-RestMethod -Method Get -Uri $URI -Headers $token_Header
$result.value



# not equals to
$URI = "https://graph.microsoft.com/v1.0/users?`$filter=displayName ne 'Alex Wilber'&`$count=true"
$result = Invoke-RestMethod -Method Get -Uri $URI -Headers $token_Header_eventual
$result.value




# in (equal to a value in a collection)
$URI = "https://graph.microsoft.com/v1.0/users?`$filter=displayName in ('Alex Wilber', 'Adele Vance')&`$count=true"
$result = Invoke-RestMethod -Method Get -Uri $URI -Headers $token_Header
$result.value



# not and in (Not equal to a value in a collection)
$URI = "https://graph.microsoft.com/v1.0/users?`$filter=not(displayName in ('Alex Wilber', 'Adele Vance'))&`$count=true"
$result = Invoke-RestMethod -Method Get -Uri $URI -Headers $token_Header_eventual





# startsWith (value starts with)
$URI = "https://graph.microsoft.com/v1.0/users?`$filter=startsWith(displayName, 'Alex')&`$count=true"
$result = Invoke-RestMethod -Method Get -Uri $URI -Headers $token_Header_eventual




# not and startsWith (value does not start with)
$URI = "https://graph.microsoft.com/v1.0/users?`$filter=not(startsWith(displayName, 'Alex'))&`$count=true"
$result = Invoke-RestMethod -Method Get -Uri $URI -Headers $token_Header_eventual




# endsWith (Value ends with)
$URI = "https://graph.microsoft.com/v1.0/users?`$filter=endsWith(UserprincipalName, 'Brown@8knn7n.onmicrosoft.com')&`$count=true"
$result = Invoke-RestMethod -Method Get -Uri $URI -Headers $token_Header_eventual





# not and endsWith (Value does not end with)
$URI = "https://graph.microsoft.com/v1.0/users?`$filter=not(endsWith(UserPrincipalName, 'Brown@8knn7n.onmicrosoft.com'))&`$count=true"
$result = Invoke-RestMethod -Method Get -Uri $URI -Headers $token_Header_eventual





# multiple operators in one single query
# OR
$URI = "https://graph.microsoft.com/v1.0/users?`$filter=startsWith(displayName, 'Alex') or startsWith(displayName, 'Adele')&`$count=true"
$result = Invoke-RestMethod -Method Get -Uri $URI -Headers $token_Header_eventual




# AND
$URI = "https://graph.microsoft.com/v1.0/users?`$filter=startsWith(displayName, 'Alex') and startsWith(Department, 'testdepartment')&`$count=true"
$result = Invoke-RestMethod -Method Get -Uri $URI -Headers $token_Header_eventual


#endregion




#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#
