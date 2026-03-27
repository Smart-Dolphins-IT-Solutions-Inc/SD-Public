#Requires -RunAsAdministrator
#Config Nuget Repository
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
Write-Host "Configuring NuGet Repository for PowerShell Gallery..." -ForegroundColor Green 
Find-PackageProvider -Name NuGet | Install-PackageProvider -Force -ErrorAction SilentlyContinue
Register-PackageSource -Name nuget.org -Location https://www.nuget.org/api/v2 -ProviderName NuGet -ErrorAction SilentlyContinue
Set-PackageSource -Name nuget.org -Trusted -ErrorAction SilentlyContinue
#Prompt for Autopilot Registration or ImmyBot Installation
$autopilot = New-Object System.Management.Automation.Host.ChoiceDescription "&Autopilot", "Register this device with Autopilot."
$immy = New-Object System.Management.Automation.Host.ChoiceDescription "&ImmyBot", "No Autopilot for you, install generic ImmyBot Agent."
$options1 = [System.Management.Automation.Host.ChoiceDescription[]]@($autopilot, $immy)
# Define the title, message, and default choice (0 for Autopilot, 1 for Immybot)
$title = "Configure Autopilot or Install ImmyBot Generic Agent?"
$message = "Pick your path for this device, Autopilot registration is recommended for managed Tenants, ImmyBot is recommended for clients with Intune Registration Policies (No BusinessPremium)."
$defaultChoice = 0 # Default to Autopilot
$result = $host.ui.PromptForChoice($title, $message, $options, $defaultChoice)
#Process the result using a switch statement
switch ($result) {
    0 {
        Write-Host "Registering device with Autopilot..." -ForegroundColor Green
    }
    1 {
        Write-Host "Deploying ImmyBot Generic Agent..." -ForegroundColor Yellow
        # Add ImmyBot deployment logic here
        $ErrorActionPreference = "Stop";$url = 'https://smartdolphins.immy.bot/plugins/api/v1/1/installer/latest-download';$InstallerFile = [io.path]::ChangeExtension([io.path]::GetTempFileName(), ".msi");(New-Object System.Net.WebClient).DownloadFile($url, $InstallerFile);$InstallerLogFile = [io.path]::ChangeExtension([io.path]::GetTempFileName(), ".log");$Arguments = " /c msiexec /i `"$InstallerFile`" /qn /norestart /l*v `"$InstallerLogFile`" REBOOT=REALLYSUPPRESS ID=8397c9e6-3222-4d35-8dec-0d66ee5c78f4 ADDR=https://smartdolphins.immy.bot/plugins/api/v1/1 KEY=qJDNjWrw4vbQ94ChOzpFrJqBJj/S3nRNooaFQ3ryf2k=";Write-Host "InstallerLogFile: $InstallerLogFile";$Process = Start-Process -Wait cmd -ArgumentList $Arguments -Passthru;if ($Process.ExitCode -ne 0) {    Get-Content $InstallerLogFile -ErrorAction SilentlyContinue | Select-Object -Last 200;    throw "Exit Code: $($Process.ExitCode), ComputerName: $($env:ComputerName)"}else {    Write-Host "Exit Code: $($Process.ExitCode)";    Write-Host "ComputerName: $($env:ComputerName)";}
        Write-Host "ImmyBot Generic Agent deployed successfully, continue with OOBE." -ForegroundColor Green
        Exit
    }
}
#Get registration script
Write-Host "Installing Microsoft Graph PowerShell Module..." -ForegroundColor Green
$env:Path += ";C:\Program Files\WindowsPowerShell\Scripts"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Install-Module -Name Microsoft.Graph.DeviceManagement -Force -ErrorAction Stop
Import-Module Microsoft.Graph.DeviceManagement -Force -ErrorAction Stop
Install-Script -Name Get-WindowsAutopilotInfo -Force -ErrorAction Stop
#Register and Dump Hardware ID Locally
Write-Host "Registering device with Autopilot and dumping hardware hash to C:\AutopilotHWID.csv..." -ForegroundColor Green
Get-WindowsAutopilotInfo -Online -OutputFile C:\AutopilotHWID.csv -ErrorAction Stop
#Wait for Input to reboot
Write-Host "Verify that the hardware hash uploaded successfully and the device is showing in Intune (will show as has ID for name)." -ForegroundColor Red
Write-Host "Once IDs are registered, Add to Autopilot Onboarding group and assign Primary User." -ForegroundColor Red
Write-Host "----------------------------------------------------" -ForegroundColor Red

#Prompt for reboot
# Define the choices
$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Reboot the system."
$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Abort Reboot and resubmit HWIDs."
$abort = New-Object System.Management.Automation.Host.ChoiceDescription "&Abort", "Abort the script."
$options = [System.Management.Automation.Host.ChoiceDescription[]]@($yes, $no, $abort)

# Define the title, message, and default choice (0 for Yes, 1 for No, 2 to Abort)
$title = "Ready for reboot into Autopilot?"
$message = "Intune check: System has been assigned to group and primary user?"
$defaultChoice = 0 # Default to Yes

# Prompt the user for a choice
$result = $host.ui.PromptForChoice($title, $message, $options, $defaultChoice)

# Process the result using a switch statement
switch ($result) {
    0 {
        Write-Host "Rebooting system and initiating Autopilot Onboarding..." -ForegroundColor Green
        Restart-Computer
    }
    1 {
        Write-Host "Resubmitting Hardware IDs, please refresh and recheck the device in Intune." -ForegroundColor Yellow
        Get-WindowsAutopilotInfo -Online -ErrorAction Stop
        Write-Host "Hardware IDs resubmitted, please verify the device is showing in Intune and assigned to Autopilot Onboarding group and Primary User." -ForegroundColor Green
        #Reprompt for reboot
        $options = [System.Management.Automation.Host.ChoiceDescription[]]@($yes, $abort)
        $result = $host.ui.PromptForChoice($title, $message, $options, $defaultChoice)
        switch ($result) {
            0 {
                Write-Host "Rebooting system and initiating Autopilot Onboarding..." -ForegroundColor Green
                Restart-Computer
            }
            1 {
                Write-Host "Aborting script execution. Please reboot system and verify endpoint manually before running the script again, system may register after reboot." -ForegroundColor Red
                Write-Host "For manual registration, see hardware IDs in C:\AutopilotHWID.csv and upload to Intune." -ForegroundColor Red
                exit
            }
        }
    }
    2 {
        Write-Host "Aborting script execution. Please reboot system and verify endpoint manually before running the script again, system may register after reboot." -ForegroundColor Red
        Write-Host "For manual registration, see hardware IDs in C:\AutopilotHWID.csv and upload to Intune." -ForegroundColor Red
        exit
    }
}
