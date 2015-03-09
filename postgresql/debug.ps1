#region Helper functions for input
function Get-Input
{
param
(
[string]$Message
)
    $variable = ""
    do { $variable = Read-Host $message } while($variable -eq "")
    return $variable
}

function Get-Password
{
param
(
[string]$Message
)
    $variable = ""
    do { $variable = Read-Host $message -AsSecureString } while($variable -eq "")
    return $variable
}
#endregion

$affinityGroup = "PGSQLAff"
$storageAccount =  "pgsqlstorage"
$networkName =  "pgsqlnet"
$vnetAddressPrefix = "10.0.0.0/8"
$subnetName = "dbs"
$databaseSubnetPrefix = "10.0.0.0/24"
$cloudServiceName =  "pgsabbour"
$availabilitySetName =  "pgavset"
$centosImageName = (Get-AzureVMImage | ? {$_.ImageName -Like "*OpenLogic-CentOS-70*"} | select -Last 1).ImageName
$vmUsername = "azureuser"
$vmPassword = "p@ssw0rd.postgresql"
$vmBaseName = "postgresql"
$vm1StaticIP = "10.0.0.5"
$vm2StaticIP = "10.0.0.6"
$internalLoadBalancerName = "postgresqllb"
$internalLoadBalancerIP = "10.0.0.100"
$dataDiksSizeGB = "50"

# Set default storage account
Set-AzureSubscription -SubscriptionName (Get-AzureSubscription –Current).SubscriptionName -CurrentStorageAccount $storageAccount

# Create VM configurations
$vm1Configuration = New-AzureVMConfig -Name ($vmBaseName + "01") -InstanceSize Standard_A1 -ImageName $centosImageName
$vm2Configuration = New-AzureVMConfig -Name ($vmBaseName + "02") -InstanceSize Standard_A1 -ImageName $centosImageName

# Add Availability Set configuration
$vm1Configuration = Set-AzureAvailabilitySet -AvailabilitySetName $availabilitySetName -VM $vm1Configuration
$vm2Configuration = Set-AzureAvailabilitySet -AvailabilitySetName $availabilitySetName -VM $vm2Configuration

# Add provisioning configuration
$vm1Configuration = Add-AzureProvisioningConfig -Linux -LinuxUser $vmUsername -Password $vmPassword -VM $vm1Configuration
$vm2Configuration = Add-AzureProvisioningConfig -Linux -LinuxUser $vmUsername -Password $vmPassword -VM $vm2Configuration

# Add networking configuration
$vm1Configuration = Set-AzureStaticVNetIP -IPAddress $vm1StaticIP -VM $vm1Configuration
$vm2Configuration = Set-AzureStaticVNetIP -IPAddress $vm2StaticIP -VM $vm2Configuration
$vm1Configuration = Set-AzureSubnet -SubnetNames $subnetName -VM $vm1Configuration
$vm2Configuration = Set-AzureSubnet -SubnetNames $subnetName -VM $vm2Configuration

# Add data disk configuration 
$vm1Configuration = Add-AzureDataDisk -CreateNew -DiskSizeInGB $dataDiksSizeGB -DiskLabel ($vmBaseName + "01-DataDisk01") -LUN 0 -VM $vm1Configuration
$vm1Configuration = Add-AzureDataDisk -CreateNew -DiskSizeInGB $dataDiksSizeGB -DiskLabel ($vmBaseName + "01-DataDisk02") -LUN 1 -VM $vm1Configuration
$vm2Configuration = Add-AzureDataDisk -CreateNew -DiskSizeInGB $dataDiksSizeGB -DiskLabel ($vmBaseName + "02-DataDisk01") -LUN 0 -VM $vm2Configuration
$vm2Configuration = Add-AzureDataDisk -CreateNew -DiskSizeInGB $dataDiksSizeGB -DiskLabel ($vmBaseName + "02-DataDisk02") -LUN 1 -VM $vm2Configuration

# Add internal load balancer configuration
$ilbConfig = New-AzureInternalLoadBalancerConfig -InternalLoadBalancerName $internalLoadBalancerName -StaticVNetIPAddress $internalLoadBalancerIP -SubnetName $subnetName

# Add Endpoint on the Internal Load Balancer pointing to port 5432 (PostgreSQL default)
$loadBalancedPort = 5432
$vm1Configuration = Add-AzureEndpoint -Name "PostgreSQL" -LBSetName "PostgreSQLSet" -Protocol tcp -LocalPort $loadBalancedPort -PublicPort $loadBalancedPort -ProbePort $loadBalancedPort -ProbeProtocol tcp -ProbeIntervalInSeconds 5 -InternalLoadBalancerName $internalLoadBalancerName -VM $vm1Configuration
$vm2Configuration = Add-AzureEndpoint -Name "PostgreSQL" -LBSetName "PostgreSQLSet" -Protocol tcp -LocalPort $loadBalancedPort -PublicPort $loadBalancedPort -ProbePort $loadBalancedPort -ProbeProtocol tcp -ProbeIntervalInSeconds 5 -InternalLoadBalancerName $internalLoadBalancerName -VM $vm2Configuration

# Set the CustomScript extension to continue setup once the VMs are created
$PublicConfiguration = '{"fileUris":["https://raw.githubusercontent.com/sabbour/azure-automation/master/postgresql/CustomScripts/finalize-postgresql.sh"], "commandToExecute": "./finalize-postgres.sh" }' 

# Deploy the extension to the VM, pick up the latest version of the extension
$ExtensionName = 'CustomScriptForLinux'  
$Publisher = 'Microsoft.OSTCExtensions'  
$Version = '1.*' 
$vm1Configuration = Set-AzureVMExtension -ExtensionName $ExtensionName -VM  $vm1Configuration -Publisher $Publisher -Version $Version -PublicConfiguration $PublicConfiguration
$vm2Configuration = Set-AzureVMExtension -ExtensionName $ExtensionName -VM  $vm2Configuration -Publisher $Publisher -Version $Version -PublicConfiguration $PublicConfiguration

# Create the VMs
New-AzureVM -ServiceName $cloudServiceName -VMs $vm1Configuration,$vm2Configuration -VNetName $networkName -InternalLoadBalancerConfig $ilbConfig -Verbose


