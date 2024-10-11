### Mastering Microsoft Graph API

#region me endpoint

#https://developer.microsoft.com/en-us/graph/graph-explorer

#https://developer.microsoft.com/en-us/microsoft-365/dev-program

# Get the current user
#auth header for my user

Connect-AzAccount
Disconnect-AzAccount

$token = (Get-AzAccessToken -ResourceTypeName MSGraph).Token

#decode token with https://jwt.ms/

$authHeader = @{ 
    Authorization = "Bearer $($token)"  
}

$token = "get token from graph explorer"

# why i am using $() in the string? 
#Use this when you want to use an expression within another expression. For example, to embed the results of command in a string expression.

$me = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/me" -Headers $authHeader


$photo = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/me/photo/`$value" -Headers $authHeader -ContentType image/jpeg -OutFile "C:\temp\photo.jpg"

# why the $value is escaped with a backtick? 

#We have to escape the dollar sign with a backtick (`) to prevent PowerShell from interpreting it as a variable.

#endregion

#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#

#region create app registration

#Create Azure APP Registration 
#Name : Global Azure Hamburg

#endregion

#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#




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

#endregion

#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#




#region Get all users in the Entra ID tenant -->  what is wrong here ? 

$users = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/users" -Headers $token_Header

$users.value

$users.value.count

$users = @()



#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#






#region asign role to app



#Assign a role  (i need to ad an role assigment to an application)

#get principal id
$appName = "Global Azure Hamburg"
$URI = "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=displayName eq '$appName'"
$myapp = Invoke-RestMethod -Method Get -Uri $URI -Headers $token_Header
$ServicePrincipalId = $myapp.value.id 


# Get all role assignments for the app
$URI = "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments?`$filter=principalId eq '$ServicePrincipalId'&`$expand=roleDefinition"
$response = (Invoke-RestMethod -Method Get -Uri $URI -Headers $token_Header).value


#Get Role Definition ID

#get all roles and filter for the display name   why not to use where object ? 
Measure-Command {
$URI = "https://graph.microsoft.com/v1.0/roleManagement/directory/roleDefinitions"
$allroles = Invoke-RestMethod -Method Get -Uri $URI -Headers $token_Header
$allroles.value | Where-Object {$_.displayName -eq "Global Reader"}
}
#or get a specific role

Measure-Command {

#$roleName = "Groups Administrator"
$roleName = "Global Reader"
$URI = "https://graph.microsoft.com/v1.0/roleManagement/directory/roleDefinitions?`$filter=displayName eq '$roleName'"
$GlobalReaderRole = (Invoke-RestMethod -Method Get -Uri $URI -Headers $token_Header).value

}

#
$URI = "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments"

$Body = @{
    "principalId" = "$($ServicePrincipalId)" #or object id of the enterprise app
    "roleDefinitionId" = "$($GlobalReaderRole.id)"
    "directoryScopeId" = "/" 
}



Invoke-RestMethod -Method Post -Uri $URI -Body ($Body | ConvertTo-Json) -Headers $token_Header

$response = $response | where-object {$_.roleDefinition.displayName -eq "Groups Administrator"}

foreach($assigment in $response){
    
    $URI = "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments/$($assigment.id)"
    Invoke-RestMethod -Method Delete -Uri $URI -Headers $token_Header

}





#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#



#endregion



