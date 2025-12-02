# Install Azure PowerShell module
Install-Module -Name Az -AllowClobber -Scope CurrentUser

# Log in to Azure Tenant
Connect-AzAccount -TenantId <TENANT-ID>

# Retrieve all subscriptions
$subscriptions = Get-AzSubscription
$emptyResourceGroups = @()

# Loop through subscriptions
foreach ($subscription in $subscriptions) {
    Write-Output "Subscription: $($subscription.Name)"
    
    # Set context to the current subscription
    Set-AzContext -SubscriptionId $subscription.Id

    # Get resource groups in the current subscription
    $resourceGroups = Get-AzResourceGroup

    # Loop through each resource group
    foreach ($rg in $resourceGroups) {
        Write-Output "Resourcegroup: $($rg.ResourceGroupName)"
        # Get resources of group
        $resourcesInGroup = Get-AzResource -ResourceGroupName $rg.ResourceGroupName

        # add to emptyResourceGroups if empty
        if ($resourcesInGroup.Count -eq 0) {
            $emptyResourceGroups += [PSCustomObject]@{
                SubscriptionName = $subscription.Name
                ResourceGroupName = $rg.ResourceGroupName
            }
        }

        Write-Output "----------------------------------------"
    }
}

# Output list of empty resource groups
Write-Output "List of all empty resource groups in all subscriptions:"
$emptyResourceGroups | Sort-Object SubscriptionName, ResourceGroupName | Format-Table -Property SubscriptionName, ResourceGroupName
