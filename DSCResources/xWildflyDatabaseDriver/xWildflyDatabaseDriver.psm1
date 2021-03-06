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
		$DriverModuleName,

		[System.String]
		$DriverClass,

		[System.String]
		$XaDatasourceClass,

		[System.String]
		$SourcePath,

		[System.String]
		$DestinationPath,

		[System.String]
		$FileName,

		[System.String]
		$ConfigFile,

		[System.String]
		$ConfigDir
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

    # Store results
	$result= @{
		FolderExists = Test-Path -Path $DestinationPath
		ModuleXmlExists = Test-Path -Path "$DestinationPath\$FileName"
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
		$DriverModuleName,

		[System.String]
		$DriverClass,

		[System.String]
		$XaDatasourceClass,

		[System.String]
		$SourcePath,

		[System.String]
		$DestinationPath,

		[System.String]
		$FileName,

		[System.String]
		$ConfigFile,

		[System.String]
		$ConfigDir
    )

    #Write-Verbose "Use this cmdlet to deliver information about command processing."

    #Write-Debug "Use this cmdlet to write debug information while troubleshooting."

    #Include this line if the resource requires a system reboot.
    #$global:DSCMachineStatus = 1

	# Check ensure value
	switch ($Ensure)
	{
		"Present"
		{
			# Check to make sure file folder exists
			if ((Test-Path -Path $DestinationPath) -eq $false)
			{
				# Display
				Write-Verbose "Creating folder $DestinationPath"
			
				# Create the folder
				New-Item -Path $DestinationPath -Force -ItemType Directory
			}

			# Check to see if the file exists
			if ((Test-Path -Path "$DestinationPath\$FileName") -eq $false)
			{
				# Display
				Write-Verbose "Copying $FileName to $DestinationPath"
			
				# Copy the file
				Copy-Item -Path "$SourcePath" -Destination "$DestinationPath\$FileName" -Force
			}

			# Set the contents of the module
			Write-Verbose "Writing module.xml"
			$xmlString = "<?xml version=`"1.0`" encoding=`"UTF-8`"?><module xmlns=`"urn:jboss:module:1.5`" name=`"$DriverModuleName`"><resources><resource-root path=`"$FileName`" /></resources><dependencies><module name=`"javax.api`"/><module name=`"javax.transaction.api`"/></dependencies></module>"
			Set-Content -Path "$DestinationPath\module.xml" -Value $xmlString

			# Load configuration xml file
			[xml]$xmlDoc = Get-Content -Path "$ConfigDir\$ConfigFile"

			# Find all drivers nodes
			$driversNodeCollection = $xmlDoc.GetElementsByTagName("drivers")
			$driverNode = $null

			# Display
			Write-Verbose "Found $($driversNodeCollection.Count) <drivers> nodes."

			# Loop through list
			foreach ($driversNode in $driversNodeCollection)
			{
				# Check to see if the node has the node
				if (($driversNode.ChildNodes | Where-Object {$_.Name -eq $Name}) -eq $null)
				{
					# Create new driver node
					$driverNode = $xmlDoc.CreateElement("driver", $driversNode.NamespaceURI)

					# Add driver node to dirviersNode
					$driversNode.AppendChild($driverNode)
				}
				else
				{
					# Get reference to driver node
					$driverNode = ($driversNode.ChildNodes | Where-Object {$_.Name -eq $Name})

					# loop through nodes
					while($driverNode.ChildNodes.Count -gt 0)
					{
						# Remove node
						$driverNode.RemoveChild($driverNode.ChildNodes[0])
					}
				}

				# Set attributes
				$driverNode.SetAttribute("name", $Name)
				$driverNode.SetAttribute("module", $DriverModuleName)

				# Create driver-class element
				$driverClassNode = $xmlDoc.CreateElement("driver-class", $driverNode.NamespaceURI)
				$driverClassNode.InnerText = $DriverClass
				$driverNode.AppendChild($driverClassNode)

				# Create xa datasource class
				$xaDatasourceClassNode = $xmlDoc.CreateElement("xa-datasource-class", $driverNode.NamespaceURI)
				$xaDatasourceClassNode.InnerText = $XaDatasourceClass
				$driverNode.AppendChild($xaDatasourceClassNode)
			}
		}
		"Absent"
		{
			# Check to make sure file folder exists
			if ((Test-Path -Path $DestinationPath) -eq $true)
			{
				# Delete it
				Remove-Item -Path $DestinationPath -Force
			}

			# Load configuration xml file
			[xml]$xmlDoc = Get-Content -Path "$ConfigDir\$ConfigFile"

			# Find all drivers nodes
			$driversNodeCollection = $xmlDoc.GetElementsByTagName("drivers")
			
			# Loop through the collection
			foreach ($driversNode in $driversNodeCollection)
			{
				# Get reference to node
				$driverNode = $driversNode.ChildNodes | Where-Object {$_.Name -eq $Name}	

				# Check for driver
				if ($driverNode -ne $null)
				{
					# Remove the node
					$driverNode.ParentNode.RemoveChild($driverNode)
				}
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
		$DriverModuleName,

		[System.String]
		$DriverClass,

		[System.String]
		$XaDatasourceClass,

		[System.String]
		$SourcePath,

		[System.String]
		$DestinationPath,

		[System.String]
		$FileName,

		[System.String]
		$ConfigFile,

		[System.String]
		$ConfigDir
    )

    #Write-Verbose "Use this cmdlet to deliver information about command processing."

    #Write-Debug "Use this cmdlet to write debug information while troubleshooting."


    <#
    $result = [System.Boolean]
    
    $result
    #>
    $desiredState = $true


    switch($Ensure)
    {
        "Present"
        {
			# Test to see if folder exists
			if ((Test-Path -Path $DestinationPath) -eq $false)
			{
				# Not in desired state
				$desiredState = $false

				break
			}
		
			# Test to see if file exists
			if ((Test-Path -Path "$DestinationPath\$FileName") -eq $false)
			{
				# Not in desired state
				$desiredState = $false

				break
			}

			# Build what the should be
			$xmlString = "<?xml version=`"1.0`" encoding=`"UTF-8`"?><module xmlns=`"urn:jboss:module:1.5`" name=`"$DriverModuleName`"><resources><resource-root path=`"$FileName`" /></resources><dependencies><module name=`"javax.api`"/><module name=`"javax.transaction.api`"/></dependencies></module>"

			# Test contents
			if ((Get-Content -Path "$DestinationPath\module.xml") -ne $xmlString)
			{
				# Not in desired state
				$desiredState = $false

				break
			}

			# Load configuration xml file
			[xml]$xmlDoc = Get-Content -Path "$ConfigDir\$ConfigFile"

			# Find all drivers nodes
			$driversNodeCollection = $xmlDoc.GetElementsByTagName("drivers")

			# Loop through list
			foreach ($driversNode in $driversNodeCollection)
			{
				# Check to see if the node has the node
				if (($driversNode.ChildNodes | Where-Object {$_.Name -eq $Name}) -eq $null)
				{
					# Not in desired state
					$desiredState = $false

					# Stop processing
					break
				}
				else
				{
					# Get reference to the driver node
					$driverNode = ($driversNode.ChildNodes | Where-Object {$_.Name -eq $Name})

					# Compare module name
					if ($driverNode.GetAttribute("module") -ne $DriverModuleName)
					{
						# Not in desired state
						$desiredState = $false
					}
				}
			}
        }
        "Absent"
        {
			# Check to make sure file folder exists
			if ((Test-Path -Path $DestinationPath) -eq $true)
			{
				# Not in desired state
				$desiredState = $false
			}

			# Load configuration xml file
			[xml]$xmlDoc = Get-Content -Path "$ConfigDir\$ConfigFile"

			# Find all drivers nodes
			$driversNodeCollection = $xmlDoc.GetElementsByTagName("drivers")

			# Loop through list
			foreach ($driversNode in $driversNodeCollection)
			{
				# Check to see if the node has the node
				if (($driversNode.ChildNodes | Where-Object {$_.Name -eq $Name}) -ne $null)
				{
					# Not in desired state
					$desiredState = $false

					# Stop processing
					break
				}
			}
        }
    }

    # Check for desired state
    if ($desiredState -and ($desiredState -eq $true))
    {
        # Display
        Write-Verbose "Database driver $Name is in desired state, no action required"
        
        # return result
        return $true
    }
    else
    {
        # Display
        Write-Verbose "Database driver $Name is not in desired state"

        # return result
        return $false
    }
}

 
Export-ModuleMember -Function *-TargetResource

