function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

		[CimInstance[]]
		$PoolOptions,

		[CimInstance[]]
		$TimeoutOptions,

		[System.String]
		$TransactionIsolation,

        [System.String]
        $Ensure,

        [System.String]
        $JNDIName,

        [System.String]
        $DriverName,

        [System.String]
        $DriverClass,

        [System.String]
        $ConnectionUrl,

        [System.Management.Automation.PSCredential]
        $Credential,

        [System.String]
        $SecurityDomain,

        [parameter(Mandatory = $true)]
        [System.String]
        $ConfigDir,

        [parameter(Mandatory = $true)]
        [System.String]
        $ConfigFile,

        [parameter(Mandatory = $true)]
        [System.String]
        $Profile,

        [System.String]
        $Enabled
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

    # Get all the datasource nodes in the specified profile
    $domainProfile = $xmlDoc.GetElementsByTagName("profile") | Where-Object {$_.name -eq $Profile}

    # Get datasource nodes
    $dataSources = $domainProfile.GetElementsByTagName("datasource")

    # Save the results
    $results = @()

    ForEach ($dataSource in $dataSources)
    {
        $results += $dataSource.'pool-name'
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

		[CimInstance[]]
		$PoolOptions,

		[CimInstance[]]
		$TimeoutOptions,

		[System.String]
		$TransactionIsolation,		

        [System.String]
        $Ensure,

        [System.String]
        $JNDIName,

        [System.String]
        $DriverName,

        [System.String]
        $DriverClass,

        [System.String]
        $ConnectionUrl,

        [System.Management.Automation.PSCredential]
        $Credential,

        [System.String]
        $SecurityDomain,

        [parameter(Mandatory = $true)]
        [System.String]
        $ConfigDir,

        [parameter(Mandatory = $true)]
        [System.String]
        $ConfigFile,

        [parameter(Mandatory = $true)]
        [System.String]
        $Profile,

        [System.String]
        $Enabled
    )

    #Write-Verbose "Use this cmdlet to deliver information about command processing."

    #Write-Debug "Use this cmdlet to write debug information while troubleshooting."

    #Include this line if the resource requires a system reboot.
    #$global:DSCMachineStatus = 1


    # Load xml document
    [xml]$xmlDoc = Get-Content -Path "$ConfigDir\$ConfigFile"

    # Get all the datasource nodes in the specified profile
    $domainProfile = $xmlDoc.GetElementsByTagName("profile") | Where-Object {$_.name -eq $Profile}

    # Get datasource nodes
    $dataSources = $domainProfile.GetElementsByTagName("datasource")
    $dataSourcesNode = $domainProfile.GetElementsByTagName("datasources")
	$dataSource = $null

    switch($Ensure)
    {
        "Present"
        {
            # Check for the existance of the datasource
            if (($dataSources | Where-Object {$_.'pool-name' -eq $Name}) -ne $null)
            {
                # Display 
                Write-Verbose "Updating datasource $Name in profile $Profile"
                
                # get reference to specific datasource
                $dataSource = $dataSources | Where-Object {$_.'pool-name' -eq $Name}

                # Set the properties of the datasource
                $dataSource.SetAttribute("jndi-name", $JNDIName)
                $dataSource.SetAttribute("pool-name", $Name)
                $dataSource.SetAttribute("jta", "true")
                $dataSource.SetAttribute("enabled", $Enabled)
                $dataSource.SetAttribute("use-ccm", "true")

                # Get reference to connection url node
				$connectionNode = $dataSource.ChildNodes | Where-Object {$_.LocalName -eq "connection-url"}
				$connectionNode.InnerText = $ConnectionUrl

				# Get reference to driver class
				#$driverClassNode = $dataSource.ChildNodes | Where-Object {$_.LocalName -eq "driver-class"}
				#$driverClassNode.InnerText = $DriverClass
				
				# Get reference to driver node
				$driverNode = $dataSource.ChildNodes | Where-Object {$_.LocalName -eq "driver"}
				$driverNode.InnerText = $DriverName

				# Check the security node
				$securityNode = $dataSource.ChildNodes | Where-Object {$_.LocalName -eq "security"}
				
				# Check for null
				if ($securityNode -ne $null)
				{
					# Loop through child nodes
					while ($securityNode.ChildNodes.Count -gt 0)
					{
						# Remove node
						$securityNode.RemoveChild($securityNode.ChildNodes[0])
					}
				}
				else
				{
					# Create security node
					$securityNode = $xmlDoc.CreateElement("security", $datasource.NamespaceURI)

					# Append to datasource
					$dataSource.AppendChild($securityNode)
				}

				# Check for credential parameter
				if($Credential -ne $null)
				{
					# Create credential nodes
					$userNameNode = $xmlDoc.CreateElement("user-name", $dataSource.NamespaceURI)
					$passwordNode = $xmlDoc.CreateElement("password", $dataSource.NamespaceURI)

					# Set values
					$userNameNode.InnerText = $Credential.UserName
					$passwordNode.InnerText = $Credential.GetNetworkCredential().Password

					# Append nodes to security node
					$securityNode.AppendChild($userNameNode)
					$securityNode.AppendChild($passwordNode)
				}
				elseif (![string]::IsNullOrEmpty($SecurityDomain))
				{
					# Create security domain node
					$securityDomainNode = $xmlDoc.CreateElement("security-domain", $dataSource.NamespaceURI)

					# Set value
					$securityDomainNode.InnerText = $SecurityDomain

					# Append to security node
					$securityNode.AppendChild($securityDomainNode)
				}

                $dataSource.enabled = $Enabled
            }
            else
            {
                # Display
                Write-Verbose "Creating datasource $Name in profile $Profile"
                
                # Create new Datasource entry
                $dataSource = $xmlDoc.CreateElement("datasource", $dataSourcesNode.NamespaceURI)

                # Fill in the datasource node attributes
                $dataSource.SetAttribute("jndi-name", $JNDIName)
                $dataSource.SetAttribute("pool-name", $Name)
                $dataSource.SetAttribute("jta", "true")
                $dataSource.SetAttribute("enabled", $Enabled)
                $dataSource.SetAttribute("use-ccm", "true")
                
                # Create subnodes
                $dataSourceConnectionUrl = $xmlDoc.CreateElement("connection-url", $dataSourcesNode.NamespaceURI)
                $dataSourceConnectionUrl.InnerText = $ConnectionUrl
                $dataSource.AppendChild($dataSourceConnectionUrl)

                $dataSourceDriverClass = $xmlDoc.CreateElement("driver-class", $dataSourcesNode.NamespaceURI)
                $dataSourceDriverClass.InnerText = $DriverClass
                $dataSource.AppendChild($dataSourceDriverClass)

                $dataSourceDriver = $xmlDoc.CreateElement("driver", $dataSourcesNode.NamespaceURI)
                $dataSourceDriver.InnerText = $DriverName
                $dataSource.AppendChild($dataSourceDriver)

                $dataSourceSecurity = $xmlDoc.CreateElement("security", $dataSourcesNode.NamespaceURI)
                
				# Check to see if Credential was specified
				if ($Credential)
				{
					$securityUserName = $xmlDoc.CreateElement("user-name", $dataSourcesNode.NamespaceURI)
					$securityPassword = $xmlDoc.CreateElement("password", $dataSourcesNode.NamespaceURI)
					$securityUserName.InnerText = $Credential.UserName
					$securityPassword.InnerText = $Credential.GetNetworkCredential().Password
					$dataSourceSecurity.AppendChild($securityUserName)
					$dataSourceSecurity.AppendChild($securityPassword)
				}
				elseif($SecurityDomain)
				{
					# Create new security-domain node
					$securityDomainNode = $xmlDoc.CreateElement("security-domain")
					$securityDomainNode.InnerText = $SecurityDomain

					# Add child
					$dataSourceSecurity.AppendChild($securityDomainNode)
				}

                $dataSource.AppendChild($dataSourceSecurity)

                $dataSourceValidation = $xmlDoc.CreateElement("validation", $dataSourcesNode.NamespaceURI)
                $validationConnectionChecker = $xmlDoc.CreateElement("valid-connection-checker", $dataSourcesNode.NamespaceURI)
                $validationBackground = $xmlDoc.CreateElement("background-validation", $dataSourcesNode.NamespaceURI)
                $validationConnectionChecker.SetAttribute("class-name", "org.jboss.jca.adapters.jdbc.extensions.mssql.MSSQLValidConnectionChecker")
                $validationBackground.InnerText = "true"
                $dataSourceValidation.AppendChild($validationConnectionChecker)
                $dataSourceValidation.AppendChild($validationBackground)
                $dataSource.AppendChild($dataSourceValidation)

                $dataSourcesNode.AppendChild($dataSource)
            }

			# Get reference to pool node
			$poolNode = $dataSource.ChildNodes | Where-Object {$_.Name -eq "pool"}

			# Check for null
			if ($poolNode -ne $null)
			{
				# Remove
				while ($poolNode.ChildNodes.Count -gt 0)
				{
					# Remove
					$poolNode.RemoveChild($poolNode.ChildNodes[0])
				}
			}
			else
			{
				# Create the pool node
				$poolNode = $xmlDoc.CreateElement("pool", $dataSourcesNode.NamespaceURI)

				# Attach to parent
				$dataSource.AppendChild($poolNode)
			}

			# Check to see if there are any pool options
			if ($PoolOptions -ne $null)
			{
				# Loop through the pool options
				foreach ($option in $PoolOptions)
				{
					# Create the Node
					$optionNode = $xmlDoc.CreateElement($option.key.ToLower(), $poolNode.NamespaceURI)

					# Set the inner text
					$optionNode.InnerText = $option.value

					# Append to poolnode
					$poolNode.AppendChild($optionNode) 
				}
			}

			# Get reference to timeout options
			$timeoutNode = $dataSources.ChildNodes | Where-Object {$_.Name -eq "timeout"}

			# Check to see if it's null
			if ($timeoutNode -ne $null)
			{
				# Loop through all of the options
				while($timeoutNode.ChildNodes.Count -gt 0)
				{
					# Remove the node
					$timeoutNode.RemoveChild($timeoutNode.ChildNodes[0])
				}
			}
			else
			{
				# Create the node
				$timeoutNode = $xmlDoc.CreateElement("timeout", $dataSource.NamespaceURI)

				# Append to xml
				$dataSource.AppendChild($timeoutNode)
			}

			# Check to see if timeout options are set
			if ($TimeoutOptions -ne $null)
			{
				# loop through the timeout options
				foreach ($option in $TimeoutOptions)
				{
					# Create new node
					$optionNode = $xmlDoc.CreateElement($option.key.ToLower(), $timeoutNode.NamespaceURI)

					# Set value
					$optionNode.InnerText = $option.value

					# append to timeoutnode
					$timeoutNode.AppendChild($optionNode)
				}
			}

			# Check transaction isolation level
			if (![string]::IsNullOrEmpty($TransactionIsolation))
			{
				# Get reference to node
				$transactionIsolationNode = $dataSource.ChildNodes | Where-Object {$_.Name -eq "transaction-isolation"}

				# Check for null
				if ($transactionIsolationNode -eq $null)
				{
					# Create the new node
					$transactionIsolationNode = $xmlDoc.CreateElement("transaction-isolation", $dataSource.NamespaceURI)

					# Add to datasource node
					$dataSource.AppendChild($transactionIsolationNode)
				}

				# Update value
				$transactionIsolationNode.InnerText = $TransactionIsolation
			}
			else
			{
				# Check to see if the node exists
				if($dataSource.ChildNodes | Where-Object {$_.Name -eq "transaction-isolation"})
				{
					# Remove the node 
					$dataSource.RemoveChild(($dataSource.ChildNodes | Where-Object {$_.Name -eq "transaction-isolation"}))
				}
			}
        }
        "Absent"
        {
            # Display
            Write-Verbose "Removing datasource $Name from profile $Profile"
            
            $dataSource = $dataSources | Where-Object {$_.'pool-name' -eq $Name}
            #$dataSourcesNode.datasources.RemoveChild($dataSource)
            $dataSource.ParentNode.RemoveChild($datasource)
        }
    }

    # Save the document
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

		[CimInstance[]]
		$PoolOptions,

		[CimInstance[]]
		$TimeoutOptions,

		[System.String]
		$TransactionIsolation,		

        [System.String]
        $Ensure,

        [System.String]
        $JNDIName,

        [System.String]
        $DriverName,

        [System.String]
        $DriverClass,

        [System.String]
        $ConnectionUrl,

        [System.Management.Automation.PSCredential]
        $Credential,

        [System.String]
        $SecurityDomain,

        [parameter(Mandatory = $true)]
        [System.String]
        $ConfigDir,

        [parameter(Mandatory = $true)]
        [System.String]
        $ConfigFile,

        [parameter(Mandatory = $true)]
        [System.String]
        $Profile,

        [System.String]
        $Enabled
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

    # Get all the datasource nodes in the specified profile
    $domainProfile = $xmlDoc.GetElementsByTagName("profile") | Where-Object {$_.name -eq $Profile}

    # Get datasource nodes
    $dataSources = $domainProfile.GetElementsByTagName("datasource")



    switch($Ensure)
    {
        "Present"
        {
            # Check for the existance of the datasource
            if (($dataSources | Where-Object {$_.'pool-name' -eq $Name}) -ne $null)
            {
                # Get reference to the specific datasource
                $dataSource = $dataSources | Where-Object {$_.'pool-name' -eq $Name}

                # Test the specific properties
                if ($dataSource.'jndi-name' -ne $JNDIName)
                {
                    # not in desired state
                    $desiredState = $false

                    # Break from if
                    break
                }

                if ($Credential)
				{
					if ($dataSource.'driver-class' -ne $DriverClass)
					{
						# Not in desired state
						$desiredState = $false

						break
					}
				}
				elseif(![string]::IsNullOrEmpty($SecurityDomain))
				{
					# Get reference to security node
					$securityNode = $dataSource.ChildNodes | Where-Object {$_.Name -eq "security"}
					$securityDomainNode = $securityNode.ChildNodes | Where-Object {$_.Name -eq "security-domain"}

					# Check the value
					if ($securityDomainNode.InnerText -ne $SecurityDomain)
					{
						# Not in desired state
						$desiredState = $false
					}
				}

                if ($dataSource.driver -ne $DriverName)
                {
                    # Not in desired state
                    $desiredState = $false

                    break
                }

                if ($dataSource.'connection-url' -ne $ConnectionUrl)
                {
                    # Not in desired state
                    $desiredState = $false

                    break
                }

                if ($dataSource.security.'user-name' -ne $Credential.UserName)
                {
                    # Not in desired state
                    $desiredState = $false

                    break
                }

                if ($dataSource.enabled -ne $Enabled)
                {
                    # Not in desired state
                    $desiredState = $false
                }

				if (!$dataSource.pool -and ($PoolOptions.Length -gt 0))
				{
					# Not in desired state
					$desiredState = $false
				}
				else
				{
					# Get reference to pool node
					$poolNode = $dataSource.ChildNodes | Where-Object {$_.Name -eq "pool"}

					# Compare counts
					if($poolNode.ChildNodes.Count -ne $PoolOptions.Length)
					{
						# Not in desired state
						$desiredState = $false
					}
					else
					{
						# Loop through options to see if they're present
						ForEach($option in $PoolOptions)
						{
							# Check for the node
							if(($poolNode.ChildNodes | Where-Object {$_.Name -eq $option.key}) -eq $null)
							{
								# Not in desired state
								$desiredState = $false

								# No need for further processing
								break
							}
							else
							{
								# Get the child node
								$childNode = $poolNode.ChildNodes | Where-Object {$_.Name -eq $option.key}

								# Compare value
								if ($childNode.InnerText -ne $option.value)
								{
									# Not in desired state
									$desiredState = $false

									# break
									break
								}
							}
						}
					}
				}

				# Check timeout options
				if (!$dataSource.timeout -and $TimeoutOptions.Length -gt 0)
				{
					# Not in desired state
					$desiredState = $false
				}
				else
				{
					# Get timeout node
					$timeoutNode = $dataSources.ChildNodes | Where-Object {$_.Name -eq "timeout"}

					# Compare counts
					if($timeoutNode.ChildNodes.Count -ne $TimeoutOptions.Length)
					{
						# Not in desired state
						$desiredState = $false
					}
					else
					{
						# Compare values
						ForEach ($option in $TimeoutOptions)
						{
							# Check for existance
							if(($timeoutNode.ChildNodes | Where-Object {$_.Name -eq $option.key}) -eq $null)
							{
								# Not in desired state
								$desiredState = $false

								# Break
								break
							}
							else
							{
								# Get reference to node
								$childNode = $timeoutNode.ChildNodes | Where-Object {$_.Name -eq $option.key}

								# Compare values
								if($childNode.InnerText -ne $option.value)
								{
									# Not in desired state
									$desiredState = $false
								}
							}
						}
					}
				}

				# Test transaction isolation
				if (!$dataSource.'transaction-isolation' -and !([String]::IsNullOrEmpty($TransactionIsolation)))
				{
					# Not in desired state
					$desiredState = $false
				}
				else
				{
					# Get reference to the node
					$transactionIsolationNode = $dataSources.ChildNodes | Where-Object {$_.Name -eq 'transaction-isolation'}
									
					if ($transactionIsolationNode -and ([String]::IsNullOrEmpty($TransactionIsolation)))
					{
						$desiredState = $false
					}	
					# Test value
					elseif ($transactionIsolationNode.InnerText -ne $TransactionIsolation)
					{
						# Not in desired state
						$desiredState = $false
					}
				}
            }
            else
            {
				# datasource not found
                $desiredState = $false
            }
        }
        "Absent"
        {
            if (($dataSources | Where-Object {$_.'pool-name' -eq $Name}) -ne $null)
            {
                # Datasource found
                $desiredState = $false
            }
            else
            {
                # Datasource wasn't found
                $desiredState = $true
            }
        }
    }

    # Check for desired state
    if ($desiredState -and ($desiredState -eq $true))
    {
        # Display
        Write-Verbose "Datasource $Name is in desired state, no action required"
        
        # return result
        return $true
    }
    else
    {
        # Display
        Write-Verbose "Datasource $Name is not in desired state"

        # return result
        return $false
    }
}

 
Export-ModuleMember -Function *-TargetResource

