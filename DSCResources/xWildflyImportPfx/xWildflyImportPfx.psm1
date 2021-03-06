function Get-CertificateFingerprintFromJavaKeystore
{
	# Declare parameters
	Param
	(
		$ArgumentList
	)

	# Use the .NET approach so that we can capture output into a variable, the PowerShell Start-Process only gives the option to store output
	# within files.

	# Declare working variables
	$standardOutput = $null
	$standardError = $null

	# Create the process info object
	$startInfo = New-Object System.Diagnostics.ProcessStartInfo

	# Fill in properties of object
	$startInfo.FileName = "$($env:JAVA_HOME)\bin\keytool.exe"
	$startInfo.Arguments = $ArgumentList
	$startInfo.RedirectStandardError = $true
	$startInfo.RedirectStandardOutput = $true
	$startInfo.UseShellExecute = $false
	$startInfo.CreateNoWindow = $true

	# Create process object
	$processObject = New-Object System.Diagnostics.Process

	# Set properties
	$processObject.StartInfo = $startInfo

	# Execute the process - ensure the output of start is not captured in the return
	$processObject.Start() | Out-Null

	# Capture any output to variables
	$standardOutput = $processObject.StandardOutput.ReadToEnd()
	$standardError = $processObject.StandardError.ReadToEnd()

	# Wait for completion
	$processObject.WaitForExit()

	# Check the exit code
	if ($processObject.ExitCode -ne 0)
	{
		# Throw an error
		throw $standardOutput
	}

	# Parse output into string array
	$standardOutput = $standardOutput.Split("`r`n")

	# Extract fingerprint
	$fingerPrint = $standardOutput | Where-Object {$_ -like "*SHA1:*"}
	$fingerPrint =  $fingerPrint.Substring($fingerPrint.IndexOf(":")).Replace(" ", "").Replace(":", "")

	# return the fingerprint (aka thumbprint)
	return $fingerPrint
}

Function Get-ThumbprintFromFile
{
    # Define parameters
    Param(
    $FilePath,
    $Credential)

    # Certificate file variable
    #$certificateFile = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
    $certificateFile = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection

    
    switch($FilePath.SubString($FilePath.LastIndexOf(".")).ToLower())
    {
        {($_ -eq ".p7b") -or ($_ -eq ".cer")}
        #".cer"
        {
            # Import the certificate file
            $certificateFile.Import($FilePath) | Out-Null
        }
        ".pfx"
        {
            # Extract password from Credential object
            $pfxPassword = $Credential.GetNetworkCredential().Password

            # Import the certificate file
            $certificateFile.Import($FilePath, $pfxPassword, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::DefaultKeySet)
        }
    }
    
    # Return the thumbprint
    #return $certificateFile.Thumbprint
    if($certificateFile.Count -gt 1)
    {
        return $certificateFile.Thumbprint[$certificateFile.Count - 1]
    }
    else
    {
        return $certificateFile.Thumbprint
    }
}


function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $SourceKeystoreName,

        [parameter(Mandatory = $true)]
        [System.String]
        $DestinationKeystoreName,

		[System.String]
		$Ensure,

        [parameter(Mandatory = $true)]
        [System.String]
        $ConfigDir,

		[parameter(Mandatory = $true)]
        [System.String]
        $ConfigFile,

		[parameter(Mandatory = $true)]
		[System.Management.Automation.PSCredential]
		$PfxPassword,

		[parameter(Mandatory = $true)]
		[System.Management.Automation.PSCredential]
		$StorePassword,

		[System.String]
		$SecurityRealm,

		[parameter(Mandatory = $true)]
		[System.String]
		$SourceStoreType,

		[parameter(Mandatory = $true)]
		[System.String]
		$DestinationStoreType
    )

    # Load xml document
    [xml]$xmlDoc = Get-Content -Path "$ConfigDir\$ConfigFile"

    # Get the management node
    $managementNode = $xmlDoc.GetElementsByTagName("management")

	# Get all of the security realm nodes
	$securityRealmsNode = $managementNode.GetElementsByTagName("security-realms")

	# Get the specific security realm
	$securityRealmNode = $securityRealmsNode.ChildNodes | Where-Object {$_.name -eq $SecurityRealm}

	# Get all of teh server identities nodes
	$serverIdentities = $securityRealmNode.ChildNodes | Where-Object {$_.LocalName -eq "server-identities"}

	# Get the node with the ssl child node
	$sslNode = $serverIdentities.ChildNodes | Where-Object {$_.LocalName -eq "ssl"}

	# Get the keystore node
	$keystoreNode = $sslNode.ChildNodes | Where-Object {$_.LocalName -eq "keystore"}

	# Send back the result
	$result = @{
		Path = $keystoreNode.GetAttribute("path")
		KeyStoreExists = Test-Path -Path "$ConfigDir\$KeystoreFileName"
	}

    # Return the result
    return $result

}


function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $SourceKeystoreName,

        [parameter(Mandatory = $true)]
        [System.String]
        $DestinationKeystoreName,

		[System.String]
		$Ensure,

        [parameter(Mandatory = $true)]
        [System.String]
        $ConfigDir,

		[parameter(Mandatory = $true)]
        [System.String]
        $ConfigFile,

		[parameter(Mandatory = $true)]
		[System.Management.Automation.PSCredential]
		$PfxPassword,

		[parameter(Mandatory = $true)]
		[System.Management.Automation.PSCredential]
		$StorePassword,

		[System.String]
		$SecurityRealm,

		[parameter(Mandatory = $true)]
		[System.String]
		$SourceStoreType,

		[parameter(Mandatory = $true)]
		[System.String]
		$DestinationStoreType
    )

    # Load xml document
    [xml]$xmlDoc = Get-Content -Path "$ConfigDir\$ConfigFile"

    # Get the management node
    $managementNode = $xmlDoc.GetElementsByTagName("management")

	# Get all of the security realm nodes
	$securityRealmsNode = $managementNode.GetElementsByTagName("security-realms")

	# Get the specific security realm
	$securityRealmNode = $securityRealmsNode.ChildNodes | Where-Object {$_.name -eq $SecurityRealm}

	# Get all of teh server identities nodes
	$serverIdentities = $securityRealmNode.ChildNodes | Where-Object {$_.LocalName -eq "server-identities"}

	# Get the node with the ssl child node
	$sslNode = $serverIdentities.ChildNodes | Where-Object {$_.LocalName -eq "ssl"}

	# Get the keystore node
	$keystoreNode = $sslNode.ChildNodes | Where-Object {$_.LocalName -eq "keystore"}

	# Get passwords
	$storePass = $StorePassword.GetNetworkCredential().Password
	$sourcePassword = $PfxPassword.GetNetworkCredential().Password

    # determine action
    switch($Ensure)
    {
        "Present"
        {
			# Check to see if the file exists
			if ((Test-Path -Path "$ConfigDir\$DestinationKeystoreName") -eq $true)
			{
				# Display
				Write-Verbose "Deleting $ConfigDir\$DestinationKeystoreName"
			
				# Delete the keystore file
				Remove-Item -Path "$ConfigDir\$DestinationKeystoreName" -Force
			}

			# Display
			Write-Verbose "Importing .pfx $SourceKeystoreName to keystore $ConfigDir\$DestinationKeystoreName"

			# Build argument list
			$argumentList = "-v -importkeystore -srckeystore `"$SourceKeystoreName`" -srcstoretype `"$SourceStoreType`" -destkeystore `"$DestinationKeystoreName`" -deststoretype `"$DestinationStoreType`" -storepass `"$storePass`" -srcstorepass `"$sourcePassword`" "

			# Change the location
			Set-Location -Path $ConfigDir

			# Import the keystore
			$importKeystore = Start-Process -FilePath "$($env:JAVA_HOME)\bin\keytool.exe" -WorkingDirectory $ConfigDir -ArgumentList $argumentList -Wait -NoNewWindow -PassThru #-RedirectStandardError "C:\temp\error.txt" -RedirectStandardOutput "C:\temp\output.txt"

			# Check exit code
			if ($importKeystore.ExitCode -eq 0)
			{
				# Display
				Write-Verbose "Successfully imported $SourceKeystoreName"
			}
			else
			{
				throw "Import failed!"
			}

			# Check keystore node
			if ($keystoreNode -eq $null)
			{
				# Create new keystore node
				$keystoreNode = $xmlDoc.CreateElement("keystore", $sslNode.NamespaceURI)

				# Add to ssl node
				$sslNode.AppendChild($keystoreNode)
			}

			# Set the keystore node attributes
			$keystoreNode.SetAttribute("path", $DestinationKeystoreName)
			$keystoreNode.SetAttribute("relative-to", "jboss.domain.config.dir")
			$keystoreNode.SetAttribute("keystore-password", $storePass)
			$keystoreNode.SetAttribute("alias", "1")
        }
        "Absent"
        {
			# Check for existance of file
			if ((Test-Path -Path "$ConfigDir\$KeystoreFileName") -eq $true)
			{
				# Remove file
				Remove-Item -Path "$ConfigDir\$KeystoreFileName"
			}

			# Check to see if keystore node is null
			if ($keystoreNode -ne $null)
			{
				# Remove from xml
				$keystoreNode.ParentNode.RemoveChild($keystoreNode)
			}
        }
    }

	# Save the changes to xml
	$xmlDoc.Save("$ConfigDir\$ConfigFile")
}


function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $SourceKeystoreName,

        [parameter(Mandatory = $true)]
        [System.String]
        $DestinationKeystoreName,

		[System.String]
		$Ensure,

        [parameter(Mandatory = $true)]
        [System.String]
        $ConfigDir,

		[parameter(Mandatory = $true)]
        [System.String]
        $ConfigFile,

		[parameter(Mandatory = $true)]
		[System.Management.Automation.PSCredential]
		$PfxPassword,

		[parameter(Mandatory = $true)]
		[System.Management.Automation.PSCredential]
		$StorePassword,

		[System.String]
		$SecurityRealm,

		[parameter(Mandatory = $true)]
		[System.String]
		$SourceStoreType,

		[parameter(Mandatory = $true)]
		[System.String]
		$DestinationStoreType
    )

	# Declare working variables
	$desiredState = $true

    # Load xml document
    [xml]$xmlDoc = Get-Content -Path "$ConfigDir\$ConfigFile"

    # Get the management node
    $managementNode = $xmlDoc.GetElementsByTagName("management")

	# Get all of the security realm nodes
	$securityRealmsNode = $managementNode.GetElementsByTagName("security-realms")

	# Get the specific security realm
	$securityRealmNode = $securityRealmsNode.ChildNodes | Where-Object {$_.name -eq $SecurityRealm}

	# Get all of teh server identities nodes
	$serverIdentities = $securityRealmNode.ChildNodes | Where-Object {$_.LocalName -eq "server-identities"}

	# Get the node with the ssl child node
	$sslNode = $serverIdentities.ChildNodes | Where-Object {$_.LocalName -eq "ssl"}

	# Get the keystore node
	$keystoreNode = $sslNode.ChildNodes | Where-Object {$_.LocalName -eq "keystore"}

    # determine action
    switch($Ensure)
    {
        "Present"
        {
			# Check to see if file exists
			if ((Test-Path -Path "$ConfigDir\$DestinationKeystoreName") -eq $false)
			{
				# Not in desired state
				$desiredState = $false

				break
			}

			# Check to see if teh keystore nod exists
			if ($keystoreNode -eq $null)
			{
				# Not in desired state
				$desiredState = $false
				
				break
			}

			# Compare path
			if ($keystoreNode.GetAttribute("path") -ne $DestinationKeystoreName)
			{
				# Not in desired state
				$desiredState = $false

				break
			}

			# Compare store password
			if ($keystoreNode.GetAttribute("keystore-password") -ne $StorePassword.GetNetworkCredential().Password)
			{
				# Not in desired state
				$desiredState = $false

				break
			}

			# Create argument list
			$argumentList = "-v -list -keystore `"$ConfigDir\$DestinationKeystoreName`" -storepass `"$($StorePassword.GetNetworkCredential().Password)`""

			# Compare thumbprint to fingerprint
			if ((Get-ThumbprintFromFile -FilePath $SourceKeystoreName -Credential $PfxPassword) -ne (Get-CertificateFingerprintFromJavaKeystore -ArgumentList $argumentList))
			{
				# Not in desired state
				$desiredState = $false
			}
        }
        "Absent"
        {
			# Check to see if the keystore node exists
			if (($keystoreNode -ne $null) -and ($keystoreNode.GetAttribute("path") -eq $DestinationKeystoreName))
			{
				# Not in desired state
				$desiredState = $false

				break
			}

			# Check to see if file exists
			if ((Test-Path -Path "$ConfigDir\$DestinationKeystoreName") -eq $true)
			{
				# Not in desired state
				$desiredState = $false
			}
        }
    }
	
	    
    if($desiredState)
    {
        Write-Verbose "Wildfly keystore in desired state, no action required."
    }
    else
    {
        Write-Verbose "Wildfly keystore is not in desired state."
    }

    return $desiredState
}


Export-ModuleMember -Function *-TargetResource

