# Input bindings are passed in via param block.
param($myTimer)

# Get the current universal time in the default string format.
$currentUTCtime = (Get-Date).ToUniversalTime()

# The 'IsPastDue' property is 'true' when the current function invocation is later than scheduled.
if ($myTimer.IsPastDue) {
    Write-Host "PowerShell timer is running late!"
}

# Write an information log with the current time.
Write-Host "PowerShell timer trigger function ran! TIME: $currentUTCtime"

# Define function variables from environment variables.
$exportPath   = "$env:HOME"
$apiVersion   = "$env:apiVersion"
$organization = "$env:devopsOrg"
$project      = "$env:devopsProj"
$repositoryId = "$env:repositoryID"
$branchName   = "$env:branch"

# Define the base URL.
$baseUrl = "https://dev.azure.com/$organization/$project/_apis/git/repositories"

# Define the push URL.
$pushUrl = "$baseUrl/$repositoryId/pushes?api-version=$apiVersion"

# Define the check last commit URL.
$commitUrl = "$baseUrl/$repositoryId/commits?api-version=$apiVersion"

# Authenticate to Azure using Managed Identity and set the subscription context.
Connect-AzAccount -Identity
Set-AzContext -Subscription "$env:subscriptionToExport"

# Get an object with a token for the Azure DevOps REST API as a secure string.
$tokenResponse = Get-AzAccessToken -ResourceUrl "499b84ac-1321-427f-aa17-267ca6975798" -AsSecureString

# Store the token with System.Security.SecureString.
$secureToken = $tokenResponse.Token

# Convert the token to plain text for HTTP headers.
$token = [System.Net.NetworkCredential]::new("", $secureToken).Password

# Display the current subscription name.
$currentSubscription = (Get-AzContext).Subscription.Name
Write-Host "Exporting resource groups for subscription: $currentSubscription" -ForegroundColor Green

# Get all resource groups in the subscription.
$resourceGroups = Get-AzResourceGroup

# Set headers for the following Azure DevOps API requests.
$headers = @{
    Authorization = "Bearer $token"
    ContentType   = "application/json"
}

# Loop through each resource group in the subscription.
foreach ($rg in $resourceGroups) {
    # Define the output file name based on the resource group name.
    $outputFile = Join-Path -Path $exportPath -ChildPath "$($rg.ResourceGroupName)-template.json"

    # Export the resource group to the specified file.
    Export-AzResourceGroup -ResourceGroupName $rg.ResourceGroupName -Path $outputFile -Force
    Write-Host "Exported $($rg.ResourceGroupName) to $outputFile"

    # Get the latest commit ID on the branch.
    $commitResponse = Invoke-RestMethod -Uri $commitUrl -Headers $headers

    # Extract the latest commit ID.
    if ($commitResponse.value.Count -gt 0) {
        $latestCommitId = $commitResponse.value[0].commitId
        Write-Host "Latest commit ID: $latestCommitId"
    } else {
        Write-Host "No commits found in the repository." -ForegroundColor Red
        exit
    }

    # Read the content of the file and encode it as base64.
    $fileContent = Get-Content -Path $outputFile -Raw
    $base64Content = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($fileContent))

    # Check if the file exists in the repository at the specific commit.
    $checkFileUrl = "$baseUrl/$repositoryId/items?path=/$($rg.ResourceGroupName)-template.json&api-version=$apiVersion&versionDescriptor.version=$branchName"

    try {
        Invoke-RestMethod -Uri $checkFileUrl -Method Get -Headers $headers
        Write-Host "File exists, set changeType to edit"
        $changeType = "edit"
    } catch {
        Write-Host "File does not exist, set changeType to add"
        $changeType = "add"
    }

    # Prepare the request body based on the existence of the file.
    $body = @{
        refUpdates = @(@{
            name        = "refs/heads/$branchName"
            oldObjectId = $latestCommitId
        })
        commits    = @(@{
            comment = "Updated or created $($rg.ResourceGroupName)-template.json file."
            changes = @(@{
                changeType = $changeType
                item       = @{
                    path = "/$($rg.ResourceGroupName)-template.json"
                }
                newContent = @{
                    content     = $base64Content
                    contentType = "base64encoded"
                }
            })
        })
    }

    # Convert the body to JSON with explicit conversion.
    $bodyJson = $body | ConvertTo-Json -Depth 10

    # Debugging: Print the body before sending the request.
    Write-Host "Request Body (JSON format): $bodyJson"

    # Send the request to Azure DevOps to push the commit.
    try {
        $response = Invoke-RestMethod -Uri $pushUrl -Method Post -Headers $headers -Body $bodyJson -ContentType "application/json"
        Write-Host "Response: $($response | ConvertTo-Json -Depth 10)"
    } catch {
        Write-Host "Error sending request: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Stack Trace: $($_.Exception.StackTrace)"
    }
}
