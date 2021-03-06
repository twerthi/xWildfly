function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $KeystoreFileName,

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
		$StorePassword,

		[System.Management.Automation.PSCredential]
		$KeyPassword,

		[parameter(Mandatory = $true)]
		[System.String]
		$CommonName,

		[parameter(Mandatory = $true)]
		[System.String]
		$OrganizationalUnit,

		[parameter(Mandatory = $true)]
		[System.String]
		$Organization,

		[parameter(Mandatory = $true)]
		[System.String]
		$Locale,

		[parameter(Mandatory = $true)]
		[System.String]
		$State,

		[parameter(Mandatory = $true)]
		[System.String]
		$Country,

		[System.String]
		$Alias,

		[System.String]
		$SecurityRealm,

		[parameter(Mandatory = $true)]
		[System.String]
		$Validity,

		[parameter(Mandatory = $true)]
		[System.String]
		$Algorithm
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
        $KeystoreFileName,

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
		$StorePassword,

		[System.Management.Automation.PSCredential]
		$KeyPassword,

		[parameter(Mandatory = $true)]
		[System.String]
		$CommonName,

		[parameter(Mandatory = $true)]
		[System.String]
		$OrganizationalUnit,

		[parameter(Mandatory = $true)]
		[System.String]
		$Organization,

		[parameter(Mandatory = $true)]
		[System.String]
		$Locale,

		[parameter(Mandatory = $true)]
		[System.String]
		$State,

		[parameter(Mandatory = $true)]
		[System.String]
		$Country,

		[System.String]
		$Alias,

		[System.String]
		$SecurityRealm,

		[parameter(Mandatory = $true)]
		[System.String]
		$Validity,

		[parameter(Mandatory = $true)]
		[System.String]
		$Algorithm
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
	$keyPass = $null

	if (![string]::IsNullOrEmpty($KeyPassword))
	{
		$keyPass = $KeyPassword.GetNetworkCredential().Password
	}


    # determine action
    switch($Ensure)
    {
        "Present"
        {
			# Check to see if the file exists
			if ((Test-Path -Path "$ConfigDir\$KeystoreFileName") -eq $false)
			{
				# Display
				Write-Verbose "Creating keystore $ConfigDir\$KeystoreFileName"


				# Build argument list
				$argumentList = "-genkey -alias `"$Alias`" -validity $Validity -keyalg $Algorithm -keystore `"$KeystoreFileName`" -storepass `"$storePass`" -dname `"CN=$CommonName, OU=$OrganizationalUnit, O=$Organization, L=$Locale, S=$State, C=$Country`""

				# Check for keypass
				if (![string]::IsNullOrEmpty($KeyPassword))
				{
					# Add keypass to argument list
					$argumentList = $argumentList + " -keypass `"$keyPass`""
				}

				# Change the location
				Set-Location -Path $ConfigDir

				# Generate the keystore
				$generateKeystore = Start-Process -FilePath "$($env:JAVA_HOME)\bin\keytool.exe" -WorkingDirectory $ConfigDir -ArgumentList $argumentList -Wait -NoNewWindow -PassThru #-RedirectStandardError "C:\temp\error.txt" -RedirectStandardOutput "C:\temp\output.txt"

				# Check exit code
				if ($generateKeystore.ExitCode -eq 0)
				{
					# Display
					Write-Verbose "Successfully generated $KeystoreFileName"
				}
				else
				{
					Write-Verbose "$($generateKeyStore.ArgumentList)"
					throw "Keystore generation failed!"
				}
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
			$keystoreNode.SetAttribute("path", $KeystoreFileName)
			$keystoreNode.SetAttribute("relative-to", "jboss.domain.config.dir")
			$keystoreNode.SetAttribute("keystore-password", $storePass)
			$keystoreNode.SetAttribute("alias", $Alias)

			# Check to see if key password was specified
			if (![string]::IsNullOrEmpty($KeyPassword))
			{
				# Set the key password
				$keystoreNode.SetAttribute("key-password", $keyPass)
			}
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
        $KeystoreFileName,

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
		$StorePassword,

		[System.Management.Automation.PSCredential]
		$KeyPassword,

		[parameter(Mandatory = $true)]
		[System.String]
		$CommonName,

		[parameter(Mandatory = $true)]
		[System.String]
		$OrganizationalUnit,

		[parameter(Mandatory = $true)]
		[System.String]
		$Organization,

		[parameter(Mandatory = $true)]
		[System.String]
		$Locale,

		[parameter(Mandatory = $true)]
		[System.String]
		$State,

		[parameter(Mandatory = $true)]
		[System.String]
		$Country,

		[System.String]
		$Alias,

		[System.String]
		$SecurityRealm,

		[parameter(Mandatory = $true)]
		[System.String]
		$Validity,

		[parameter(Mandatory = $true)]
		[System.String]
		$Algorithm
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
			if ((Test-Path -Path "$ConfigDir\$KeystoreFileName") -eq $false)
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
			if ($keystoreNode.GetAttribute("path") -ne $KeystoreFileName)
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

			# Compare alias
			if ($keystoreNode.GetAttribute("alias") -ne $Alias)
			{
				# Not in desired state
				$desiredState = $false

				break
			}

			# Check to see if Keypassword is null
			if ((![string]::IsNullOrEmpty($KeyPassword)) -and ([string]::IsNullOrEmpty($keystoreNode.GetAttribute("key-password"))))
			{
				# Not in desired state
				$desiredState = $false
			}
			elseif (([string]::IsNullOrEmpty($KeyPassword)) -and (![string]::IsNullOrEmpty($keystoreNode.GetAttribute("key-password"))))
			{
				# Not in desired state
				$desiredState = $false
			}
			elseif ($KeyPassword.GetNetworkCredential().Password -ne $keystoreNode.GetAttribute("key-password"))
			{
				# Not in desired state
				$desiredState = $false
			}
        }
        "Absent"
        {
			# Check to see if the keystore node exists
			if (($keystoreNode -ne $null) -and ($keystoreNode.GetAttribute("path") -eq $KeystoreFileName))
			{
				# Not in desired state
				$desiredState = $false

				break
			}

			# Check to see if file exists
			if ((Test-Path -Path "$ConfigDir\$KeystoreFileName") -eq $true)
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

