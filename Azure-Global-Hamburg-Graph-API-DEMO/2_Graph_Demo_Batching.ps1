### Mastering Microsoft Graph API  Batching

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



#get principal id
$appName = "Global Azure Hamburg"
$URI = "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=displayName eq '$appName'"
$myapp = Invoke-RestMethod -Method Get -Uri $URI -Headers $token_Header
$ServicePrincipalId = $myapp.value.id 


# Get all role assignments for the app
$URI = "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments?`$filter=principalId eq '$ServicePrincipalId'&`$expand=roleDefinition"
$response = (Invoke-RestMethod -Method Get -Uri $URI -Headers $token_Header).value


$response = $response | where-object {$_.roleDefinition.displayName -eq "Groups Administrator"}


foreach($assigment in $response){
    
    $URI = "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments/$($assigment.id)"
    Invoke-RestMethod -Method Delete -Uri $URI -Headers $token_Header

}

#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#




#region batching

$batcharray= @()

$id = 0

foreach($assigment in $response){
    
    $id ++
    $batchobject = @{
        "id" = $id
        "method" = "DELETE"
        "url" = "/roleManagement/directory/roleAssignments/$($assigment.id)"
    }

    $batcharray += $batchobject

}

$requestobject = @{
    "requests" = $batcharray
}

$jsonbatchrequest = $requestobject | ConvertTo-Json

$URI = "https://graph.microsoft.com/v1.0/`$batch"

$response =  Invoke-RestMethod -Method Post -Uri $URI -body $jsonbatchrequest -Headers $token_Header

$response.responses

#manual step 

#HTTP Request

#endregion


#region Batches with more then 20 requests


#get all users from the tenant

$URI = "https://graph.microsoft.com/v1.0/users"
$myUsers = Invoke-RestMethod -Method Get -Uri $URI -Headers $token_Header

$myGroup = @{
    "displayName" = "Global Azure Hamburg"
    "mailEnabled" = $false
    "mailNickname" = "GlobalAzureHamburg"
    "securityEnabled" = $true
    "visibility" = "Private"
}


$URI = "https://graph.microsoft.com/v1.0/groups"
$myGroup = Invoke-RestMethod -Method Post -Uri $URI -body ($myGroup | ConvertTo-Json) -Headers $token_Header


[array]$userRequests = @()
[int]$id = 0
# Add all users to the group and update their companyName attribute
$userRequests = $myUsers.value | ForEach-Object {
    

    @{
        id = $id++
        method = "POST"
        url = "/groups/$($myGroup.id)/members/`$ref"
        body = @{
            "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($_.id)"
        }
        headers = @{
            "Content-Type" = "application/json"
        }
    }

    $id++

    # Update user's companyName attribute
    @{
        id = $id++
        method = "PATCH"
        url = "/users/$($_.id)"
        body = @{
            companyName = "Test Company Name"
        }
        headers = @{
            "Content-Type" = "application/json"
        }
    }
}


# Create a batch request

$requests = @($groupRequest) + $userRequests

$counter = [pscustomobject] @{ Value = 0 }
$BatchgroupSize = 20
$BatchGroups = $($requests) | Group-Object -Property { [math]::Floor($counter.Value++ / $BatchgroupSize) }

$BatchGroups.Group


foreach($Group in $BatchGroups)
{
    $BatchRequests = [pscustomobject][ordered]@{ 
        requests = $($Group.Group)
    }

    $batchBody = $BatchRequests | ConvertTo-Json -Depth 6


$Batchresponse = Invoke-RestMethod -Method Post -Uri "https://graph.microsoft.com/v1.0/`$batch" -Headers $token_Header -Body $batchBody

}


#Batches doesn't support depends on over the requests. If you would like to use depends on you can always do that in a single request.


<# 
Example :  

[math]::Floor(1 / 20)   = 0,05      Group 0
[math]::Floor(2 / 20)   = 0,1       Group 0 
[math]::Floor(3 / 20)   = 0,15      Group 0
[math]::Floor(4 / 20)   = 0,2       Group 0
[math]::Floor(21 / 20)  = 1,05      Group 1
[math]::Floor(22 / 20)  = 1,1       Group 1
[math]::Floor(26 / 20)  = 1,3       Group 1
[math]::Floor(40 / 20)  = 2         Group 2
[math]::Floor(55 / 20)  = 2,75      Group 2
[math]::Floor(70 / 20)  = 3,5       Group 3
[math]::Floor(80 / 20)  = 4         Group 4
[math]::Floor(80 / 20)  = 4         Group 4
[math]::Floor(100 / 20) = 5         Group 5
[math]::Floor(110 / 20) = 5,5       Group 5
[math]::Floor(120 / 20) = 6         Group 6
#>



#Depends on 


$batchrequest = @"

    {
        "requests": [
          {
            "id": "1",
            "method": "GET",
            "url": "/users"
          },
          {
            "id": "2",
            "dependsOn": [ "1" ],
            "method": "GET",
            "url": "/groups/$($myGroup.id)"
          },
          {
            "id": "3",
            "dependsOn": [ "2" ],
            "method": "GET",
            "url": "/users/0690235c-977b-4fa4-83c3-a38313642a62"
          },
          {
            "id": "4",
            "dependsOn": [ "3" ],
            "method": "GET",
            "url": "/teams"
          }
        ]
      }

"@

$Batchresponse_dependson = Invoke-RestMethod -Method Post -Uri "https://graph.microsoft.com/v1.0/`$batch" -Headers $token_Header -Body $batchrequest


$batchrequest = @"

    {
        "requests": [
          {
            "id": "1",
            "method": "GET",
            "url": "/users"
          },
          {
            "id": "2",
            "method": "GET",
            "url": "/groups/$($myGroup.id)"
          },
          {
            "id": "3",
            "method": "GET",
            "url": "/users/0690235c-977b-4fa4-83c3-a38313642a62"
          },
          {
            "id": "4",
            "method": "GET",
            "url": "/teams"
          }
        ]
      }

"@


$Batchresponse = Invoke-RestMethod -Method Post -Uri "https://graph.microsoft.com/v1.0/`$batch" -Headers $token_Header -Body $batchrequest





#region crate 100 users in a batch

# List of European names
$firstNames = @("Liam", "Noah", "Oliver", "Elijah", "Lucas", "Mason", "Logan", "Alexander", "Ethan", "Jacob", "Emma", "Olivia", "Ava", "Sophia", "Mia", "Charlotte", "Amelia", "Harper", "Evelyn", "Abigail")
$lastNames = @("Smith", "Johnson", "Williams", "Brown", "Jones", "Miller", "Davis", "Garcia", "Rodriguez", "Wilson", "Martinez", "Anderson", "Taylor", "Thomas", "Hernandez", "Moore", "Martin", "Jackson", "Thompson", "White")

# Create user requests
$userRequests = for ($i = 1; $i -le 100; $i++) {
    $firstName = $firstNames[(Get-Random -Maximum 20)]
    $lastName = $lastNames[(Get-Random -Maximum 20)]
    @{
        id = $i
        method = "POST"
        url = "/users"
        body = @{
            accountEnabled = $false
            displayName = "$firstName $lastName"
            mailNickname = "$firstName$lastName"
            userPrincipalName = "$firstName$lastName@8knn7n.onmicrosoft.com"
            passwordProfile = @{
                forceChangePasswordNextSignIn = $true
                password = "YourS3cureP@ssword$i"
            }
            city = "Hamburg"
        }
        headers = @{
            "Content-Type" = "application/json"
        }
    }
}


$counter = [pscustomobject] @{ Value = 0 }
$BatchgroupSize = 20
$BatchGroups = $($userRequests) | Group-Object -Property { [math]::Floor($counter.Value++ / $BatchgroupSize) }


foreach($Group in $BatchGroups)
{
    $BatchRequests = [pscustomobject][ordered]@{ 
        requests = $($Group.Group)
    }

    $batchBody = $BatchRequests | ConvertTo-Json -Depth 6

$Batchresponse = Invoke-RestMethod -Method Post -Uri "https://graph.microsoft.com/v1.0/`$batch" -Headers $token_Header -Body $batchBody

}


# Create a batch request
$batchBody = @{
    requests = $userRequests
} | ConvertTo-Json -Depth 4





$URI = "https://graph.microsoft.com/v1.0/`$batch"
Invoke-RestMethod -Method Post -Uri $URI -Headers $token_Header -Body $batchBody


#endregion



#region Remove 100 Users in this Batch

# Get users from Hamburg
$URI = "https://graph.microsoft.com/v1.0/users?`$filter=city eq 'Hamburg'"
$users = Invoke-RestMethod -Method Get -Uri $URI -Headers $token_Header


# Create user delete requests
$userDeleteRequests = $users.value | ForEach-Object {
    @{
        id = $_.id
        method = "DELETE"
        url = "/users/$($_.id)"
    }
}



$counter = [pscustomobject] @{ Value = 0 }
$BatchgroupSize = 20
$BatchGroups = $($userDeleteRequests) | Group-Object -Property { [math]::Floor($counter.Value++ / $BatchgroupSize) }


foreach($Group in $BatchGroups)
{
    $BatchRequests = [pscustomobject][ordered]@{ 
        requests = $($Group.Group)
    }

    $batchBody = $BatchRequests | ConvertTo-Json -Depth 6

$Batchresponse = Invoke-RestMethod -Method Post -Uri "https://graph.microsoft.com/v1.0/`$batch" -Headers $token_Header -Body $batchBody
}

#endregion


