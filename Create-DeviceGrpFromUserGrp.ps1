# Install necessary Microsoft Graph modules, allowing overwriting of existing versions if necessary.
install-module Microsoft.Graph.Authentication -AllowClobber -Force
install-module Microsoft.Graph.Groups -AllowClobber -Force
install-module Microsoft.Graph.DeviceManagement -AllowClobber -Force

# Import the installed modules into the current PowerShell session.
import-module Microsoft.Graph.Authentication  -Force
Import-Module Microsoft.Graph.Groups  -Force
Import-Module Microsoft.Graph.DeviceManagement -Force

# Define variables for the Azure AD application ID, tenant ID, and the certificate thumbprint used for authentication.
$AADAppId = "0c0c6927-26bb-4869-8c9b-2c4991dde88d"
$AADTenantId = "55f37ed7-ebe7-4cea-8686-1ca9653384f1"
$CertificateThumbprint = "7bc60150e6b421880d31e3bba793ff4cdcad69e1"

# Retrieve the certificate from the current user's certificate store using the thumbprint.
$Cert = Get-ChildItem Cert:\CurrentUser\My\$CertificateThumbprint

# Define the names of the device and user groups to be managed.
$UserGroupName = "MarsMS CoMgmt Pilot Device Primary User Group"
$DeviceGroupName = "MarsMS CoMgmt Pilot Device Group-New" 

# Connect to Microsoft Graph using the specified credentials and certificate, suppressing the welcome message.
Connect-MgGraph -NoWelcome -ClientID $AADAppId -TenantId $AADTenantId -Certificate $Cert  -ErrorAction Stop 

# Retrieve the groups specified by their display names.
$GroupFilter = "DisplayName eq '$($DeviceGroupName)'"
$DevGroup = Get-MgGroup -Filter $GroupFilter
$UserGroup = Get-MgGroup -Filter "DisplayName eq '$($UserGroupName)'"

# Retrieve members of the device group as devices.
$DevGroupMember = Get-MgGroupMemberAsDevice -GroupId $DevGroup.ID

# Iterate through each member device in the device group.
for ($i = 0; $i -lt ($DevGroupMember.Count-1) ; $i++)
{
    $Device = $DevGroupMember[$i]
    $DeviceID = $Device.DeviceId

    # Retrieve the managed device from Microsoft Device Management using the Azure AD device ID.
    $ManagedDevice = Get-MgDeviceManagementManagedDevice -Filter "AzureADDeviceID eq '$($DeviceID)'" 
    $IntuneDeviceID = $ManagedDevice.Id 
    $PrimaryUser = Get-MgDeviceManagementManagedDeviceUser -ManagedDeviceId $IntuneDeviceID
    $DeviceDisplayName = $Device.DisplayName    
    $PrimaryUserDisplayName = $PrimaryUser.DisplayName
    $PrimaryUserId = $PrimaryUser.Id

    # Check if the device has a primary user and output the information or a message indicating no primary user.
    if ($PrimaryUserId -eq $null)
    {
      Write-Host "$DeviceDisplayName doesn't have a primary user!"
    }
    else {
      $PrimaryUserId = $PrimaryUser.Id
      Write-Host "$DeviceDisplayName has primary user $PrimaryUserDisplayName, with id $PrimaryUserId."
      
      # Add the primary user of the device to the user group.
      New-MgGroupMember -GroupId $UserGroup.Id -DirectoryObjectId $PrimaryUser.Id -ErrorAction SilentlyContinue
    }
}

# Disconnect from Microsoft Graph at the end of the script.
Disconnect-MgGraph
