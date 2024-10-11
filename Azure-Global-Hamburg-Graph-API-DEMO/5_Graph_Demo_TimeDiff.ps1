#region ms learn
#.. https://learn.microsoft.com/en-us/graph/json-batching
#endregion

#region load modules

<#

    Install-Module Microsoft.Graph.Authentication -Scope AllUsers -Force -Confirm:$false
    Install-Module Microsoft.Graph.Users.Actions -Scope AllUsers -Force -Confirm:$false
    Install-Module Microsoft.Graph.People -Scope AllUsers -Force -Confirm:$false
    Install-Module Microsoft.Graph.Users -Scope AllUsers -Force -Confirm:$false
    Install-Module Microsoft.Graph.PersonalContacts -Scope AllUsers -Force -Confirm:$false
    Install-Module Microsoft.Graph.Groups -Scope AllUsers -Force -AllowClobber -Confirm:$false
    Install-Module Microsoft.Graph.Identity.DirectoryManagement -Scope AllUsers -Force -AllowClobber -Confirm:$false

    #>


    Import-Module "C:\Users\ahmed\OneDrive\Sessions\Global Azure Hamburg\Demo\DEMO_MODULES_BATCHNG.psm1" -DisableNameChecking -Force    

    #endregion
    
    #region authentication
    #-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#
    
    #Set-Secret -Name DEMO_Contacts -Secret ""

    $TenantName = ""
    $ClientId = ""
    $ClientSecret = Get-Secret -Name DEMO_Contacts -AsPlainText
    $token = Request-AccessToken -TenantName "$TenantName" -ClientId "$ClientId" -ClientSecret "$ClientSecret"  
    $securestring = ConvertTo-SecureString -AsPlainText  $token -Force
    
    Connect-MgGraph -AccessToken $securestring -NoWelcome
    #Connect-MgGraph -
    #endregion authentication
    #-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#
    
    #region glob variables
    $GALSYNCFOLDERNAME = "CONTACTS_GLOBAL_AZURE_HAMBURG"
    $UserID = 'vornamenachname@8knn7n.onmicrosoft.com'
    #endregion
    
    #$UserID = (Get-MgUser -All | ? {$_.mail -ne $null} | select mail).Mail
    #-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#
    
    #region get contacts to sync into User Contacts Folder
    $GAL_Users = $null
    $GAL_Users = Get-GalSyncUsers -DebugPreference 'continue'
    
    $GAL_Users.count
    #endregion 
    #-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#
    #-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#
    
    #region demonstration total time wasted without batching
    
    
    
    $Usercontactfolder = Get-MgUserContactFolder -UserID $UserID | where { $_.DisplayName -eq "$($GALSYNCFOLDERNAME)" }
                
    if ($Usercontactfolder) {
        Remove-MgUserContactFolder -ContactFolderId "$($Usercontactfolder.ID)" -UserID $UserID
    }
        
    Write-Debug "Usercontactfolder existiert noch nicht und muss angelegt werden"
    $ContactFolder = $null
    $ContactFolder = New-MgUserContactFolder -UserId $UserID -DisplayName "$($GALSYNCFOLDERNAME)"
    Write-Debug "Usercontactfolder $($GALSYNCFOLDERNAME) wurde angelegt"
    
    
    $measureresults = @{}
    
    #create contacts with batches Graph API HTTP Request
    $BATCHJOBRESULT = Measure-Command { Push-GalSycnUserContacts -Contacts $GAL_Users -UserMail $UserID -ContactFolderID $($ContactFolder.Id) -DebugPreference 'Continue' -accesstoken $($token) -BatchJob $true }
    $measureresults.'Batch' = "$($BATCHJOBRESULT.Seconds) Seconds"
    
    
    #create contacts with SDK Graph Module
    $SDKGRAPHMODULERESULT = Measure-Command { Push-GalSycnUserContacts -Contacts $GAL_Users -UserMail $UserID -ContactFolderID $($ContactFolder.Id) -DebugPreference 'Continue' -accesstoken $($token) -BatchJob $false }
    $measureresults.'Graph Module' = "$($SDKGRAPHMODULERESULT.Seconds) Seconds"
    
    #create contacts with GRaph API HTTP Request
    $HTTPGRAPHRESULT = Measure-Command { Push-GalSycnUserContacts -Contacts $GAL_Users -UserMail $UserID -ContactFolderID $($ContactFolder.Id) -DebugPreference 'Continue' -accesstoken $($token) -BatchJob $false -httprequest }
    $measureresults.'Graph HTTP Request' = "$($HTTPGRAPHRESULT.Seconds) Seconds"
    
    $measureresults | Format-List
    
    
    #überlegung wenn mann 1000 User hätte
<#
    Methode                Zeit für einen Benutzer (Sekunden)    Zeit für 1000 Benutzer (Sekunden)    Zeit für 1000 Benutzer (Stunden)
    ---------------------  -----------------------------------  ----------------------------------  ---------------------------------
    Graph HTTP Request     29                                   29000                                8.06
    Batch                  5                                    5000                                 1.39
    Graph Module           17                                   17000                                4.72
#>


#Kostenrechnung. 

#29000 sekunden = 483,33 Minuten = 0,96666 € x 30 Tage = 29 € x 12 Monate = 348 €
#5000 sekunden = 83,33 Minuten = 0,16666 € x 30 Tage = 5 € x 12 Monate = 60 €
#17000 sekunden = 283,33 Minuten = 0,56666 € x 30 Tage = 17 € x 12 Monate = 204 €




    #endregion