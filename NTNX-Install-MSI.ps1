############################################################
##
## Function: NTNX-Install-MSI
## Author: Steven Poitras
## Description: Automate bulk MSI installation
## Language: PowerShell
##
############################################################
function NTNX-Install-MSI {
<#
.NAME
	NTNX-Install-MSI
.SYNOPSIS
	Installs Nutanix package to Windows hosts
.DESCRIPTION
	Installs Nutanix package to Windows hosts
.NOTES
	Authors:  thedude@nutanix.com
	
	Logs: C:\Users\<USERNAME>\AppData\Local\Temp\NutanixCmdlets\logs
.LINK
	www.nutanix.com
.EXAMPLE
    NTNX-Install-MSI -installer "Nutanix-VirtIO-1.0.0.msi" `
		-cert "NutanixSoftware.cer" -localPath "C:\" `
		-computers $compArray -credential $(Get-Credential)
		
	NTNX-Install-MSI -installer "Nutanix-VirtIO-1.0.0.msi" `
		-cert "NutanixSoftware.cer" -localPath "C:\" `
		-computers "99.99.99.99"
#> 
	Param(
		[parameter(mandatory=$true)]$installer,
		
		[parameter(mandatory=$true)]$cert,
		
		[parameter(mandatory=$false)][AllowNull()]$localPath,
		
		[parameter(mandatory=$true)][Array]$computers,
		
		[parameter(mandatory=$false)][AllowNull()]$credential,
		
		[parameter(mandatory=$false)][Switch]$force
	)

	begin{
		# Pre-req message
		Write-host "NOTE: the following pre-requisites MUST be performed / valid before script execution:"
		Write-Host "	+ Nutanix installer must be downloaded and installed locally"
		Write-Host "	+ Export Nutanix Certificate in Trusted Publishers / Certificates"
		Write-Host "	+ Both should be located in c:\ if localPath not specified"
		
		if ($force.IsPresent) {
			Write-Host "Force flag specified, continuing..."
		} else {
			$input = Read-Host "Do you want to continue? [Y/N]:"
				
			if ($input -ne 'y') {
				break
			}
		}

		
		if ($(Get-ExecutionPolicy) -ne 'Unrestricted') {
			Set-ExecutionPolicy Unrestricted -Scope CurrentUser -Force -Confirm:$false
		}
		
		$failedInstall = @()
		
		# Import modules and add snappins
		#Import-Module DnsClient

		# Installer and cert filenames
		if ([string]::IsNullOrEmpty($localPath)) {
			# Assume location is c:\
			$localPath = 'c:\'
		}
		
		# Path for ADMIN share used in transfer
		$adminShare = "C:\Windows\"
		
		# Format paths
		$localInstaller = $(Join-Path $localPath $installer)
		$localCert = $(Join-Path $localPath $cert)
		$remoteInstaller = $(Join-Path $adminShare $installer)
		$remoteCert = $(Join-Path $adminShare $cert)
		
		# Make sure files exist
		if (!(Test-Path -Path $localInstaller) -or !(Test-Path -Path $localCert)) {
			Write-Host "Warning one of more input files missing, exiting..."
			break
		}
		
		# Credential for remote PS connection
		if (!$credential) {
			$credential = Get-Credential -Message "Please enter domain admin credentials `
				Example: <SPLAB\superstevepo/*******>"
		}
	
	}
	process {
		# For each computer copy file and install drivers
		$computers | %	{
			$vmConn = $null
			
			# Find method to connect (IP or DNS)
			$vmIP = $_.Guest.IPaddress | where {$_ -notmatch ":"}
			
			$vmIP | %{
				if(Test-Connection -ComputerName $_ -Count 3 -Quiet) {
					# Connection
					Write-Host "Successful connection on IP: $_"
					
					$vmConn = $_
					
					return
				} else {
					Write-Host "Unable to connect on IP: $_"
				}
			}
			
			if ($vmConn -eq $null) {
				# No connection
				Write-Host "Unable to connect to VM, skipping..."
				return
			}
		
			# Create a new PS Drive
			New-PSDrive -Name P -PSProvider FileSystem -Root \\$vmConn\ADMIN$ `
				-Credential $credential
			
			# Copy virtio installer
			Copy-Item  $localInstaller P:\$installer
			
			# Copy Nutanix cert
			Copy-Item $localCert P:\$cert
			
			# Create PS Session
			$sessionObj = New-PSSession -ComputerName $vmConn -Credential $credential
			
			# Install certificate for signing
			Invoke-Command -session $sessionObj -ScriptBlock {
				certutil -addstore "TrustedPublisher" $args[0]
			} -Args $remoteCert
			
			# Install driver silently
			$installResponse = Invoke-Command -session $sessionObj -ScriptBlock {
				$status = Start-Process -FilePath "msiexec.exe"  -ArgumentList `
					$args[0] -Wait -PassThru
				
				return $status
			} -Args "/i $remoteInstaller /qn"
			
			if ($installResponse.ExitCode -eq 0) {
				Write-Host "Installation of Nutanix package succeeded!"
			} else {
				Write-Host "Installation of Nutanix package failed..."
				$failedInstall += $_
			}
			
			# Cleanup PS drive
			Remove-PSDrive -Name P
		
			# Cleanup session
			Disconnect-PSSession -Session $sessionObj | Remove-PSSession
		}
	
	}
	end {
		# Return objects where install failed
		return $failedInstall
	}
}