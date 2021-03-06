function Convert-CimInstanceToHashTable
{
	# Define parameters
	Param
	(
		$CimInstance
	)

	# Declare variables
	$hashTable = @{}

	# Loop through CimInstance array
	foreach ($item in $CimInstance)
	{
		# Add to ash table
		$hashTable[$item.Key] = $item.Value
	}

	# Return the hashtable
	return $hashTable
}

function Set-EncodedPassword
{
    # Define parameters
    param($Password)

    # Get string as byte array
    $bytes = [System.Text.Encoding]::ASCII.GetBytes($Password)

    # Convert and return
    return [Convert]::ToBase64String($bytes)
}


function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

		[System.String]
		$Ensure,

		[System.String]
		$ConfigFile,

		[System.String]
		$ConfigDir,

		[System.String]
		$CacheType,

		[parameter(Mandatory = $true)]
		[System.String]
		$Profile,

		[System.String]
		$LoginModuleCode,

		[System.String]
		$LoginModuleFlag,

		[CimInstance[]]
		$LoginModuleOptions,

		[System.Management.Automation.PSCredential]
        $Credential
    )

    #Write-Verbose "Use this cmdlet to deliver information about command processing."

    #Write-Debug "Use this cmdlet to write debug information while troubleshooting."


    <#
    $returnValue = @{
    Ensure = [System.String]
    ServiceName = [System.String]
    BinDir = [System.String]
    Browser = [System.String[]]
    Credential = [System.Management.Automation.PSCredential]
    }

    $returnValue
    #>

    # Load xml document
    [xml]$xmlDoc = Get-Content -Path "$ConfigDir\$ConfigFile"

	# Get reference to the specific profile
	$profileNode = $xmlDoc.GetElementsByTagName("profile") | Where-Object {$_.name -eq $Profile}

	# Get reference to the specific security-domain
	$securitySubsystemNode = $profileNode.ChildNodes | Where-Object {$_.'security-domains' -ne $null -and $_.NamespaceURI -like "urn:jboss:domain:security*"}
	$securityDomainsNode = $securitySubSystemNode.ChildNodes | Where-Object {$_.Name -eq "security-domain"}
	$securityDomainNode = $securityDomainsNode.ChildNodes | Where-Object {$_.Name -eq $Name}

    # Store results
	$result= @{
		CacheType = $securityDomainNode.'cache-type'
		Name = $Name
    }


    # return the results
    return $result
}


function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

		[System.String]
		$Ensure,

		[System.String]
		$ConfigFile,

		[System.String]
		$ConfigDir,

		[System.String]
		$CacheType,

		[parameter(Mandatory = $true)]
		[System.String]
		$Profile,

		[System.String]
		$LoginModuleCode,

		[System.String]
		$LoginModuleFlag,

		[CimInstance[]]
		$LoginModuleOptions,

		[System.Management.Automation.PSCredential]
        $Credential
    )

    #Write-Verbose "Use this cmdlet to deliver information about command processing."

    #Write-Debug "Use this cmdlet to write debug information while troubleshooting."

    #Include this line if the resource requires a system reboot.
    #$global:DSCMachineStatus = 1

    # Load xml document
    [xml]$xmlDoc = Get-Content -Path "$ConfigDir\$ConfigFile"

	# Get reference to the specific profile
	$profileNode = $xmlDoc.GetElementsByTagName("profile") | Where-Object {$_.name -eq $Profile}

	# Get reference to the specific security-domain
	$securitySubsystemNode = $profileNode.ChildNodes | Where-Object {$_.'security-domains' -ne $null -and $_.NamespaceURI -like "urn:jboss:domain:security*"}
	$securityDomainsNode = $securitySubSystemNode.ChildNodes | Where-Object {$_.Name -eq "security-domains"}
	$securityDomainNode = $securityDomainsNode.ChildNodes | Where-Object {$_.Name -eq $Name}

	# Check ensure value
	switch ($Ensure)
	{
		"Present"
		{
			# Convert the ciminstance array	
			$LoginModuleOptionsHashTable = Convert-CimInstanceToHashTable -CimInstance $LoginModuleOptions

			# Check to see if the node exists
			if ($securityDomainNode -eq $null)
			{
				# Create the new node
				$securityDomainNode = $xmlDoc.CreateElement("security-domain", $securityDomainsNode.NamespaceURI)

				# Attach to domains node
				$securityDomainsNode.AppendChild($securityDomainNode)
			}
			
			# Set attributes
			$securityDomainNode.SetAttribute("name", $Name)
			$securityDomainNode.SetAttribute("cache-type", $CacheType)

			# Get reference to authentication node
			$authenticationNode = $securityDomainNode.ChildNodes | Where-Object {$_.Name -eq "authentication"}

			# Check to see if node is null
			if ($authenticationNode -eq $null)
			{
				# Create the node
				$authenticationNode = $xmlDoc.CreateElement("authentication", $securityDomainNode.NamespaceURI)

				# Attach to parent node
				$securityDomainNode.AppendChild($authenticationNode)
			}
			
			# Get reference to the login module node
			$loginModuleNode = $authenticationNode.ChildNodes | Where-Object {$_.Name -eq "login-module"}

			# Check to see if node exists
			if ($loginModuleNode -eq $null)
			{
				# Create the node
				$loginModuleNode = $xmlDoc.CreateElement("login-module", $authenticationNode.NamespaceURI)

				# Attach to parent
				$authenticationNode.AppendChild($loginModuleNode)
			}

			# Set loginmodule attributes
			$loginModuleNode.SetAttribute("code", $LoginModuleCode)
			$loginModuleNode.SetAttribute("flag", $LoginModuleFlag)

			# Clear login module options
			while ($loginModuleNode.ChildNodes.Count -gt 0)
			{
				# Remove the node
				$loginModuleNode.RemoveChild($loginModuleNode.ChildNodes[0])
			}

			# Check to see if credential was specified
			if ($Credential -ne $null)
			{
				# Add username and password entries to LoginModuleOptions
				$LoginModuleOptionsHashTable.Add("username", $Credential.UserName)
				$LoginModuleOptionsHashTable.Add("password", (Set-EncodedPassword -Password $Credential.GetNetworkCredential().Password))
			}

			# Add the specified options
			foreach ($moduleOption in $LoginModuleOptionsHashTable.Keys)
			{
				# Create the node
				$moduleOptionNode = $xmlDoc.CreateElement("module-option", $loginModuleNode.NamespaceURI)

				# Fill in attributes
				$moduleOptionNode.SetAttribute("name", $moduleOption)
				$moduleOptionNode.SetAttribute("value", $LoginModuleOptionsHashTable[$moduleOption])

				# Add to parent
				$loginModuleNode.AppendChild($moduleOptionNode)
			}
		}
		"Absent"
		{
			# Check to see if it exists
			if ($securityDomainNode -ne $null)
			{
				# Remove the node
				$securityDomainsNode.RemoveChild($securityDomainNode)
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
        $Name,

		[System.String]
		$Ensure,

		[System.String]
		$ConfigFile,

		[System.String]
		$ConfigDir,

		[System.String]
		$CacheType,

		[parameter(Mandatory = $true)]
		[System.String]
		$Profile,

		[System.String]
		$LoginModuleCode,

		[System.String]
		$LoginModuleFlag,

		[CimInstance[]]
		$LoginModuleOptions,

		[System.Management.Automation.PSCredential]
        $Credential
    )

    #Write-Verbose "Use this cmdlet to deliver information about command processing."

    #Write-Debug "Use this cmdlet to write debug information while troubleshooting."


    <#
    $result = [System.Boolean]
    
    $result
    #>
    $desiredState = $true

    # Load xml document
    [xml]$xmlDoc = Get-Content -Path "$ConfigDir\$ConfigFile"

	# Get reference to the specific profile
	$profileNode = $xmlDoc.GetElementsByTagName("profile") | Where-Object {$_.name -eq $Profile}

	# Get reference to the specific security-domain
	$securitySubsystemNode = $profileNode.ChildNodes | Where-Object {$_.'security-domains' -ne $null -and $_.NamespaceURI -like "urn:jboss:domain:security*"}
	$securityDomainsNode = $securitySubSystemNode.ChildNodes | Where-Object {$_.Name -eq "security-domains"}
	$securityDomainNode = $securityDomainsNode.ChildNodes | Where-Object {$_.Name -eq $Name}

    switch($Ensure)
    {
        "Present"
        {
			# Convert the ciminstance array	
			$LoginModuleOptionsHashTable = Convert-CimInstanceToHashTable -CimInstance $LoginModuleOptions

			# Ensure nod exists
			if ($securityDomainNode -eq $null)
			{
				# No point in moving forward
				$desiredState = $false

				break
			}
			
			# Test to see if folder exists
			if ($securityDomainNode.GetAttribute("cache-type") -ne $CacheType)
			{
				# Not in desired state
				$desiredState = $false

				break
			}

			# Get reference to the Authentication node
			$authenticationNode = $securityDomainNode.ChildNodes | Where-Object {$_.Name -eq "authentication"}

			# Get reference to login module node
			$loginModuleNode = $authenticationNode.ChildNodes | Where-Object {$_.Name -eq "login-module"}
		
			# Make sure login module exists
			if ($loginModuleNode -ne $null)
			{
				# Test attributes
				if ($loginModuleNode.GetAttribute("code") -ne $LoginModuleCode)
				{
					# Not in desired state
					$desiredState = $false

					break
				}

				if ($loginModuleNode.GetAttribute("flag") -ne $LoginModuleFlag)
				{
					# Not in desired state
					$desiredState = $false

					break
				}

				# Test module options
				if ($loginModuleNode.ChildNodes.Count -ne $LoginModuleOptions.Length)
				{
					# Not in desired state
					$desiredState = $false

					break
				}
				else
				{
					# Check to see if the credential object was provided
					if ($Credential -ne $null)
					{
						# Add username and password entries to LoginModuleOptions
						$LoginModuleOptionsHashTable.Add("username", $Credential.UserName)
						$LoginModuleOptionsHashTable.Add("password", (Set-EncodedPassword -Password $Credential.GetNetworkCredential().Password))
					}
				
					# Test the individual entries
					foreach ($moduleOption in $LoginModuleOptionsHashTable.Keys)
					{
						# make sure the option exists
						$moduleOptionNode = $loginModuleNode.ChildNode | Where-Object {$_.Name -eq $moduleOption}

					    if ($moduleOptionNode -eq $null)
						{
							# Not in desired state
							$desiredState = $false

							break
						}
						else
						{
							# Test value
							if ($moduleOptionNode.GetAttribute("value") -ne $LoginModuleOptions[$moduleOption])
							{
								# Not in desired state
								$desiredState = $false

								break
							}
						}
					}
				}
				
			}
			else
			{
				# Not in desired state
				$desiredState = $false
			}

        }
        "Absent"
        {
			# Check to make sure file folder exists
			if ($securityDomainNode -ne $null)
			{
				# Not in desired state
				$desiredState = $false
			}
        }
    }

    # Check for desired state
    if ($desiredState -and ($desiredState -eq $true))
    {
        # Display
        Write-Verbose "Security Domain $Name is in desired state, no action required"
        
        # return result
        return $true
    }
    else
    {
        # Display
        Write-Verbose "Security Domain $Name is not in desired state"

        # return result
        return $false
    }
}

 
Export-ModuleMember -Function *-TargetResource

