#Check that the managed identity has access to the Azure DevOps organization & project and most importantly has a higher permission level than "Stakeholder", ideally at least "Basic"

# Authenticate to Azure using Managed Identity and set the subscription context.
Connect-AzAccount -Identity

# Get an object with a token for the Azure DevOps REST API as a secure string.
$tokenResponse = Get-AzAccessToken -ResourceUrl "499b84ac-1321-427f-aa17-267ca6975798" -AsSecureString

# Store the token with System.Security.SecureString.
$secureToken = $tokenResponse.Token

# Convert the token to plain text for HTTP headers.
$token = [System.Net.NetworkCredential]::new("", $secureToken).Password
