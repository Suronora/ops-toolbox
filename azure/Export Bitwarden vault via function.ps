# Input bindings are passed in via param block.
param($Timer)

# Get the current universal time in the default string format.
$currentUTCtime = (Get-Date).ToUniversalTime()

# The 'IsPastDue' property is 'true' when the current function invocation is later than scheduled.
if ($Timer.IsPastDue) {
    Write-Host "PowerShell timer is running late!"
}

# Write an information log with the current time.
Write-Host "PowerShell timer trigger function ran! TIME: $currentUTCtime"

# Set install directory of Bitwarden CLI
$installDir = "$env:TEMP\bitwarden-cli"

# Set CLI release to be downloaded
# Caution: This pulls only the specified release, not the newest release
$cliRelease = "https://github.com/bitwarden/clients/releases/download/cli-v2025.2.0/bw-oss-windows-2025.2.0.zip"

# Create the directory for Bitwarden CLI
New-Item -Path $installDir -ItemType Directory -Force

# Download the Bitwarden CLI zip file
$zipFile = "$env:TEMP\bw-oss-windows-2025.2.0.zip"
Invoke-WebRequest -Uri $cliRelease -OutFile $zipFile

# Extract the zip file to the installation directory
Expand-Archive -Path $zipFile -DestinationPath $installDir -Force

# Define path of CLI
$bwpath = "$env:TEMP\bw.exe"

# Define export path
$expath = "$env:TEMP\bworgexport.json"

# Remove the zip file after extraction
Remove-Item -Path $zipFile

# Add the Bitwarden CLI directory to the PATH environment variable for the current session
$env:PATH += ";$installDir"

# Optional: Check if Bitwarden CLI is installed successfully
# bw --version

# Define Storage Account variables & name of exported file
$staccount = "<STORAGE ACCOUNT>"
$stcontainer = "<STORAGE CONTAINER>"
$blobName ="$currentutcTime.json"
$stkey = $null

# Create hash table with each keyvault secret as key
$secrets = @(
    "bwclientid",
    "bwclientsecret",
    "orgid",
    "encryptpw",
    "stkey",
    "userpass"
)

# Get string value & set as value for each key in hash table
$secretValues = @{}
foreach ($secret in $secrets) {
    $secretValues[$secret] = (Get-AzKeyVaultSecret -VaultName "<KEYVAULT>" -Name $secret).SecretValue | ConvertFrom-SecureString -AsPlainText
}

# Create variables from corresponding key:value
$bwclientid = $secretValues["bwclientid"]
$bwclientsecret = $secretValues["bwclientsecret"]
$orgid = $secretValues["orgid"]
$encryptpw = $secretValues["encryptpw"]
$stkey = $secretValues["stkey"]
$user_pass = $secretValues["userpass"]

# Set export format
$exformat="encrypted_json"

# Set environment variables required for bw login --apikey
$env:BW_CLIENTID=$bwclientid
$env:BW_CLIENTSECRET=$bwclientsecret

# Set bw cloud region
bw config server https://vault.bitwarden.eu

[[Log]] in
bw login --apikey

# Generate session key
$session_key= bw unlock $user_pass --raw

# Generate encrypted json export for organization and save it at expath
bw export $user_pass --output $expath --format $exformat --organizationid $orgid --session $session_key --password $encryptpw

# Create a context for the storage account using the storage account key
$context = New-AzStorageContext -StorageAccountName $staccount -StorageAccountKey $stkey

# Upload the file to the specified blob container from expath
Set-AzStorageBlobContent -File $expath -Container $stcontainer -Blob $blobName -Context $context -Force

# Close bw cli session
bw logout
