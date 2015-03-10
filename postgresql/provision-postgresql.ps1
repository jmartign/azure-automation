
#region Helper functions for Azure Virtual Network
function Get-AzureNetworkXml
{
$currentVNetConfig = get-AzureVNetConfig
if ($currentVNetConfig -ne $null)
{
[xml]$workingVnetConfig = $currentVNetConfig.XMLConfiguration
} else {
$workingVnetConfig = new-object xml
}
$networkConfiguration = $workingVnetConfig.GetElementsByTagName("NetworkConfiguration")
if ($networkConfiguration.count -eq 0)
{
$newNetworkConfiguration = create-newXmlNode -nodeName "NetworkConfiguration"
$newNetworkConfiguration.SetAttribute("xmlns:xsd","http://www.w3.org/2001/XMLSchema")
$newNetworkConfiguration.SetAttribute("xmlns:xsi","http://www.w3.org/2001/XMLSchema-instance")
$networkConfiguration = $workingVnetConfig.AppendChild($newNetworkConfiguration)
}
$virtualNetworkConfiguration = $networkConfiguration.GetElementsByTagName("VirtualNetworkConfiguration")
if ($virtualNetworkConfiguration.count -eq 0)
{
$newVirtualNetworkConfiguration = create-newXmlNode -nodeName "VirtualNetworkConfiguration"
$virtualNetworkConfiguration = $networkConfiguration.AppendChild($newVirtualNetworkConfiguration)
}
$dns = $virtualNetworkConfiguration.GetElementsByTagName("Dns")
if ($dns.count -eq 0)
{
$newDns = create-newXmlNode -nodeName "Dns"
$dns = $virtualNetworkConfiguration.AppendChild($newDns)
}
$virtualNetworkSites = $virtualNetworkConfiguration.GetElementsByTagName("VirtualNetworkSites")
if ($virtualNetworkSites.count -eq 0)
{
$newVirtualNetworkSites = create-newXmlNode -nodeName "VirtualNetworkSites"
$virtualNetworkSites = $virtualNetworkConfiguration.AppendChild($newVirtualNetworkSites)
}
return $workingVnetConfig
}

function Save-AzureNetworkXml($workingVnetConfig)
{
$tempFileName = $env:TEMP + "\azurevnetconfig.netcfg"
$workingVnetConfig.save($tempFileName)
notepad $tempFileName
set-AzureVNetConfig -configurationpath $tempFileName
}

function Add-AzureVnetNetwork
{
param
(
[string]$networkName,
[string]$location,
[string]$addressPrefix
)
#check if the network already exists
$networkExists = $workingVnetConfig.GetElementsByTagName("VirtualNetworkSite") | where {$_.name -eq $networkName}
if ($networkExists.Count -ne 0)
{
write-Output "Network $networkName already exists"
$newNetwork = $null
return $newNetwork
}

#check that the target affinity group exists
#$affinityGroupExists = get-AzureAffinityGroup | where {$_.name -eq $affinityGroup}
#if ($affinityGroupExists -eq $null)
#{
#write-Output "Affinity group $affinityGroup does not exist"
#$newNetwork = $null
#return $newNetwork
#}

#get the parent node
$workingNode = $workingVnetConfig.GetElementsByTagName("VirtualNetworkSites")
#add the new network node
$newNetwork = create-newXmlNode -nodeName "VirtualNetworkSite"
$newNetwork.SetAttribute("name",$networkName)
$newNetwork.SetAttribute("Location",$location )
$network = $workingNode.appendchild($newNetwork)
#add new address space node
$newAddressSpace = create-newXmlNode -nodeName "AddressSpace"
$AddressSpace = $Network.appendchild($newAddressSpace)
$newAddressPrefix = create-newXmlNode -nodeName "AddressPrefix"
$newAddressPrefix.InnerText=$addressPrefix
$AddressSpace.appendchild($newAddressPrefix)
#return our new network
$newNetwork = $network
return $newNetwork
}

function Add-AzureVnetSubnet
{
param
(
[string]$networkName,
[string]$subnetName,
[string]$addressPrefix
)
#get our target network
$workingNode = $workingVnetConfig.GetElementsByTagName("VirtualNetworkSite") | where {$_.name -eq $networkName}
if ($workingNode.Count -eq 0)
{
write-Output "Network $networkName does not exist"
$newSubnet = $null
return $newSubnet
}
#check if the subnets node exists and if not, create
$subnets = $workingNode.GetElementsByTagName("Subnets")
if ($subnets.count -eq 0)
{
$newSubnets = create-newXmlNode -nodeName "Subnets"
$subnets = $workingNode.appendchild($newSubnets)
}
#check to make sure our subnet name doesn't exist and/or prefix isn't already there
$subNetExists = $workingNode.GetElementsByTagName("Subnet") | where {$_.name -eq $subnetName}
if ($subNetExists.count -ne 0)
{
write-Output "Subnet $subnetName already exists"
$newSubnet = $null
return $newSubnet
}
$subNetExists = $workingNode.GetElementsByTagName("Subnet") | where {$_.AddressPrefix -eq $subnetName}
if ($subNetExists.count -ne 0)
{
write-Output "Address prefix $addressPrefix already exists in another network"
$newSubnet = $null
return $newSubnet
}
#add the subnet
$newSubnet = create-newXmlNode -nodeName "Subnet"
$newSubnet.SetAttribute("name",$subnetName)
$subnet = $subnets.appendchild($newSubnet)
$newAddressPrefix = create-newXmlNode -nodeName "AddressPrefix"
$newAddressPrefix.InnerText = $addressPrefix
$subnet.appendchild($newAddressPrefix)
#return our new subnet
$newSubnet = $subnet
return $newSubnet
}

function Add-AzureVnetDns
{
param
(
[string]$dnsName,
[string]$dnsAddress
)
#check that the DNS does not exist
$dnsExists = $workingVnetConfig.GetElementsByTagName("DnsServer") | where {$_.name -eq $dnsName}
if ($dnsExists.Count -ne 0)
{
write-Output "DNS Server $dnsName already exists"
$newDns = $null
return $newDns
}
# get our working node of Dns
$workingNode = $workingVnetConfig.GetElementsByTagName("Dns")
#check if the DnsServersRef node exists and if not, create
$dnsServers = $workingNode.GetElementsByTagName("DnsServers")
if ($dnsServers.count -eq 0)
{
$newDnsServers = create-newXmlNode -nodeName "DnsServers"
$dnsServers = $workingNode.appendchild($newDnsServers)
}
#add new dns reference
$newDnsServer = create-newXmlNode -nodeName "DnsServer"
$newDnsServer.SetAttribute("name",$dnsName)
$newDnsServer.SetAttribute("IPAddress",$dnsAddress)
$newDns = $dnsServers.appendchild($newDnsServer)
#return our new dnsRef
return $newDns
}

function Add-AzureVnetDnsRef
{
param
(
[string]$networkName,
[string]$dnsName
)
#get our target network
$workingNode = $workingVnetConfig.GetElementsByTagName("VirtualNetworkSite") | where {$_.name -eq $networkName}
if ($workingNode.count -eq 0)
{
write-Output "Network $networkName does not exist"
$newSubnet = $null
return $newSubnet
}
#check if the DnsServersRef node exists and if not, create
$dnsServersRef = $workingNode.GetElementsByTagName("DnsServersRef")
if ($dnsServersRef.count -eq 0)
{
$newDnsServersRef = create-newXmlNode -nodeName "DnsServersRef"
$dnsServersRef = $workingNode.appendchild($newDnsServersRef)
}
#check that the DNS we want to reference is defined already
$dnsExists = $workingVnetConfig.GetElementsByTagName("DnsServer") | where {$_.name -eq $dnsName}
if ($dnsExists.Count -eq 0)
{
write-Output "DNS Server $dnsName does not exist so cannot be referenced"
$newDnsRef = $null
return $newDnsRef
}
#check that the dns reference isn't already there
$dnsRefExists = $workingNode.GetElementsByTagName("DnsServerRef") | where {$_.name -eq $dnsName}
if ($dnsRefExists.count -ne 0)
{
write-Output "DNS reference $dnsName already exists"
$newDnsRef = $null
return $newDnsRef
}
#add new dns reference
$newDnsServerRef = create-newXmlNode -nodeName "DnsServerRef"
$newDnsServerRef.SetAttribute("name",$dnsName)
$newDnsRef = $dnsServersRef.appendchild($newDnsServerRef)
#return our new dnsRef
return $newDnsRef
}

function Create-NewXmlNode
{
param
(
[string]$nodeName
)
$newNode = $workingVnetConfig.CreateElement($nodeName,"http://schemas.microsoft.com/ServiceHosting/2011/07/NetworkConfiguration")
return $newNode
}
#endregion

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

Write-Host "==============================================================="
Write-Host "+  This script will provision a 2-node PostgreSQL cluster.    +"
Write-Host "+                                                             +"
Write-Host "+  Make sure you have the Azure PowerShell tools configured   +"
Write-Host "+                                                             +"
Write-Host "+  Provided with no warranty by Ahmed Sabbour                 +"
Write-Host "+  http://sabbour.me                                          +"
Write-Host "+                                                             +"
Write-Host "+  Make sure you know what you're doing!                      +"
Write-Host "==============================================================="

Write-Host ""

Write-Host "Below is your current active subscription, if it is not the subscription you want,"
Write-Host "terminate the script, run Get-AzureSubscription to get all configured subscriptions"
Write-Host "then run Select-AzureSubscription –SubscriptionName <subscription> to select"
Write-Host "the subscription you desire, then re-run the script."

Get-AzureSubscription –Current

$continue = Read-Host "Continue with the above subscription? (y/n)"
if($continue -ne "y") {
# If yes was not chosen, terminate the script
Exit
}

# List Azure Locations available
Write-Host "Available Azure Locations" -BackgroundColor Black -ForegroundColor Green
(Get-AzureLocation).Name

# Inputs
Write-Host "Settings for provisioning the environment" -BackgroundColor Black -ForegroundColor Green
#$affinityGroup = Get-Input -message "Affinity group name (should be up to 100 characters)"
#$affinityGroupLocation =  Get-Input -message "Affinity group location (one of the locations above)"
#$storageAccount =  Get-Input -message "Storage account name (lowercase letters and numbers between 3-24 characters)"
#$networkName =  Get-Input -message "Network name (example: pgsqlnet)"
#$vnetAddressPrefix = Get-Input -message "Address and CIDR (example: 10.0.0.0/8)"
#$subnetName = Get-Input -message "Database subnet name (example: database)"
#$databaseSubnetPrefix = Get-Input -message "Database subnet prefix (example: 10.0.0.0)"
#$databaseSubnetCIDR = Get-Input -message "Database subnet CIDR (example: /24)"
#$cloudServiceName =  Get-Input -message "Cloud Service host name (example: postgresqlcs)"
#$availabilitySetName =  Get-Input -message "Availability Set name (example: posgresqlavset)"
#$vmUsername = Get-Input -Message "Username"
#$vmPassword = Get-Input -Message "Password"
#$vmBaseName = Get-Input -Message "Base VM name (example: postgresql)"
#$vm1StaticIP = Get-Input -Message "Static IP for VM1 (must be in the subnet you specified earlier, example: 10.0.0.5)"
#$vm2StaticIP = Get-Input -Message "Static IP for VM2 (must be in the subnet you specified earlier, example: 10.0.0.6)"
#$internalLoadBalancerName = Get-Input -Message "Internal Load Balancer name (for example postgresqllb)"
#$internalLoadBalancerIP = Get-Input -Message "Internal Load Balancer IP (must be in the subnet you specified earlier, example: 10.0.0.100)"
#$dataDiksSizeGB = Get-Input -Message "Size of Data disks in GB (example: 50)"

$affinityGroupLocation =  "North Europe"
$storageAccount =  "pgsabbourstorage"
$networkName =  "pgsqlvnet"
$vnetAddressPrefix = "10.0.0.0/8"
$subnetName = "database"
$databaseSubnetPrefix = "10.0.0.0"
$databaseSubnetCIDR = "/24"
$cloudServiceName =  "pgsqlsabbour"
$availabilitySetName =  "pgavset"
$vmUsername = "azureuser"
$vmPassword = "p@ssw0rd.123"
$vmBaseName = "pgsql"
$vm1StaticIP = "10.0.0.5"
$vm2StaticIP = "10.0.0.6"
$internalLoadBalancerName = "pgsqllb"
$internalLoadBalancerIP = "10.0.0.100"
$dataDiksSizeGB = "10"

# Create Storage Account inside the Affinity Group
Write-Host "Create the Storage Account" -BackgroundColor Black -ForegroundColor Green
New-AzureStorageAccount -StorageAccountName $storageAccount -Location $affinityGroupLocation -Type "Standard_LRS" -Description  "Storage account holding PostgreSQL cluster VHDs"

# Change the default Storage Account to this one
Write-Host "Using this Storage Account as default" -BackgroundColor Black -ForegroundColor Green
Set-AzureSubscription -SubscriptionName (Get-AzureSubscription –Current).SubscriptionName -CurrentStorageAccount $storageAccount

# Create Virtual Network
Write-Host "Create the Virtual Network" -BackgroundColor Black -ForegroundColor Green
$workingVnetConfig = get-azureNetworkXml
add-azureVnetNetwork  -location $affinityGroupLocation -networkName $networkName -addressPrefix $vnetAddressPrefix
add-azureVnetSubnet -networkName $networkName -subnetName $subnetName -addressPrefix ($databaseSubnetPrefix+$databaseSubnetCIDR)
save-azurenetworkxml($workingVnetConfig)

# Create a Cloud Service to hold the VMs
Write-Host "Create a Cloud Service to hold the machines" -BackgroundColor Black -ForegroundColor Green
New-AzureService -ServiceName $cloudServiceName -Location $affinityGroupLocation -Description "PostgreSQL Cluster Cloud Service" -Verbose

# Get the CentOS7 VM image (last one, probably most up to date)
Write-Host "Latest image of CentOS 7" -BackgroundColor Black -ForegroundColor Green
$centosImageName = (Get-AzureVMImage | ? {$_.ImageName -Like "*OpenLogic-CentOS-70*"} | select -Last 1).ImageName
Write-Host ("Using " + $centosImageName)

# Create VM configurations
$vm1Configuration = New-AzureVMConfig -Name ($vmBaseName + "01") -InstanceSize Small -ImageName $centosImageName
$vm2Configuration = New-AzureVMConfig -Name ($vmBaseName + "02") -InstanceSize Small -ImageName $centosImageName

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

# Specify the SSH endpoint
$vm1Configuration = Add-AzureEndpoint -Name "SSH" -Protocol tcp -LocalPort 22 -PublicPort 2022 -VM $vm1Configuration
$vm2Configuration = Add-AzureEndpoint -Name "SSH" -Protocol tcp -LocalPort 22 -PublicPort 2122 -VM $vm2Configuration

# Set the CustomScript extension to continue setup once the VMs are created
$PublicConfiguration = '{"fileUris":[
"https://raw.githubusercontent.com/sabbour/azure-automation/master/postgresql/CustomScripts/finalize-postgresql.sh",
"https://raw.githubusercontent.com/sabbour/azure-automation/master/postgresql/CustomScripts/configure-prerequisites.sh",
"https://raw.githubusercontent.com/sabbour/azure-automation/master/postgresql/CustomScripts/configure-drbd.sh",
"https://raw.githubusercontent.com/sabbour/azure-automation/master/postgresql/CustomScripts/configure-filesystem.sh",
"https://raw.githubusercontent.com/sabbour/azure-automation/master/postgresql/CustomScripts/configure-postgresql.sh",
"https://raw.githubusercontent.com/sabbour/azure-automation/master/postgresql/CustomScripts/configure-pacemaker.sh"], "commandToExecute": "bash ./finalize-postgresql.sh ' + ($vmBaseName + "01") + ' ' + ($vmBaseName + "02") + ' ' + $vm1StaticIP + ' ' + $vm2StaticIP + ' ' + $databaseSubnetPrefix + '" }'

# Deploy the extension to the VM, pick up the latest version of the extension
$ExtensionName = 'CustomScriptForLinux'
$Publisher = 'Microsoft.OSTCExtensions'
$Version = '1.*'
$vm1Configuration = Set-AzureVMExtension -ExtensionName $ExtensionName -VM  $vm1Configuration -Publisher $Publisher -Version $Version -PublicConfiguration $PublicConfiguration
$vm2Configuration = Set-AzureVMExtension -ExtensionName $ExtensionName -VM  $vm2Configuration -Publisher $Publisher -Version $Version -PublicConfiguration $PublicConfiguration

# Create the VMs
New-AzureVM -ServiceName $cloudServiceName -VMs $vm1Configuration,$vm2Configuration -VNetName $networkName -InternalLoadBalancerConfig $ilbConfig -Verbose
