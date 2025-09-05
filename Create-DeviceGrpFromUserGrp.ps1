# Install necessary Microsoft Graph modules, allowing overwriting of existing versions if necessary.

install-module Microsoft.Graph.Authentication -AllowClobber -Force
install-module Microsoft.Graph.Groups -AllowClobber -Force
install-module Microsoft.Graph.DeviceManagement -AllowClobber -Force
install-module Microsoft.Graph.Users -AllowClobber -Force


# Import the installed modules into the current PowerShell session.
import-module Microsoft.Graph.Authentication  -Force
Import-Module Microsoft.Graph.Groups  -Force
Import-Module Microsoft.Graph.DeviceManagement -Force
Import-Module Microsoft.Graph.Users

function Clear-GroupMember {
  param (
    [string]$GroupId
  )

  $Members = Get-MgGroupMember -GroupId $GroupId
  foreach ($Member in $Members) {
    # Remove member using the correct cmdlet for object reference
    Remove-MgGroupMemberByRef  -GroupId $GroupId -DirectoryObjectId $Member.Id
  }
}

# Define variables for the Azure AD application ID, tenant ID, and the certificate thumbprint used for authentication.
$AADAppId = "0c0c6927-26bb-4869-8c9b-2c4991dde88d"
$AADTenantId = "55f37ed7-ebe7-4cea-8686-1ca9653384f1"
$CertificateThumbprint = "75CA6C1A65EDBDC6249E8CC7F1F340B24E85406D"

# Retrieve the certificate from the current user's certificate store using the thumbprint.
$Cert = Get-ChildItem Cert:\CurrentUser\My\$CertificateThumbprint

# Define the names of the device and user groups to be managed.
$UserGroupName = "User Group - AU"
$dgWinName = "BYOD-Windows-AU" 
$dgiOSName = "BYOD-iOS-AU"
$dgAndroidName = "BYOD-Android-AU"


# Connect to Microsoft Graph using the specified credentials and certificate, suppressing the welcome message.
Connect-MgGraph -NoWelcome -ClientID $AADAppId -TenantId $AADTenantId -Certificate $Cert  -ErrorAction Stop 

$UserGroup = Get-MgGroup -Filter "DisplayName eq '$($UserGroupName)'"


# Retrieve the groups specified by their display names.
$GroupFilter = "DisplayName eq '$($dgWinName)'"
$WinDevGroup = Get-MgGroup -Filter $GroupFilter
Clear-GroupMember ($WinDevGroup.Id)

$GroupFilter = "DisplayName eq '$($dgiOSName)'"
$iOSDevGroup = Get-MgGroup -Filter $GroupFilter
Clear-GroupMember ($iOSDevGroup.Id)

$GroupFilter = "DisplayName eq '$($dgAndroidName)'"
$AndroidDevGroup = Get-MgGroup -Filter $GroupFilter
Clear-GroupMember ($AndroidDevGroup.Id)

# Get users in the user group
$Users = Get-MgGroupMember -GroupId $UserGroup.Id

foreach ($User in $Users) {
    # Get devices for each user
    # Testing the logic
    # $User = $Users[0]
    $Devices = Get-MgUserRegisteredDevice -UserId $User.Id

    Write-Host "The user is $($User.AdditionalProperties.displayName)"
    foreach ($Device in $Devices) {
      # Tesing the logic
      # $Device = $Devices[0]  
        # Check if device is Entra registered and Intune managed
        if ($Device.AdditionalProperties.trustType -eq "Workplace" `
                    -and $Device.AdditionalProperties.isManaged `
                    -and $Device.AdditionalProperties.deviceOwnership -eq "Personal") {
            Write-Host "Adding device $($Device.AdditionalProperties.displayName) of type $($Device.AdditionalProperties.operatingSystem) to the appropriate group."
            switch ($Device.AdditionalProperties.operatingSystem) {
                "Windows" {
                    New-MgGroupMember -GroupId $WinDevGroup.Id  -DirectoryObjectId $Device.Id
                }
                "iPhone" {
                    New-MgGroupMember -GroupId $iOSDevGroup.Id -DirectoryObjectId $Device.Id
                }
                "Android" {
                    New-MgGroupMember -GroupId $AndroidDevGroup.Id -DirectoryObjectId $Device.Id
                }
            }
        }
    }
}



# Disconnect from Microsoft Graph at the end of the script.
Disconnect-MgGraph 
