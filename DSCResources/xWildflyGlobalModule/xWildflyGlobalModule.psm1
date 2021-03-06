Function Copy-File
{
	# Define parameters
	Param($SourcePath,
	$DestinationPath,
	$Credential)

		# Check for null credential
		if ($Credential -ne $null)
		{
			# NOTE - This is an extremely wonky way to do this, but apparently PowerShell, in it's infinite wisdom, decided you cannot use the credential object, despite allowing it as a parameter
			$DriveLetter = Get-UnusedDriverLetter
		
			# Write some output so we know where we are
			Write-Verbose "Mapping $DriveLetter to $([System.IO.Path]::GetDirectoryName($SourcePath))"

			## Test to make sure source path actually exists
			#if ((Test-Path -Path $([System.IO.Path]::GetDirectoryName($SourcePath)) -Credential $Credential) -eq $false)
			#{
			#	# throw error
			#	throw [System.IO.FileNotFoundException] "Could not find: $([System.IO.Path]::GetDirectoryName($SourcePath))"
			#}

			# Create a new PSDrive
			New-PSDrive -Name $DriveLetter -PSProvider FileSystem -Root $([System.IO.Path]::GetDirectoryName($SourcePath)) -Credential $Credential

			# Successful mapping
			Write-Verbose "Drive $DriveLetter mapped to $([System.IO.Path]::GetDirectoryName($SourcePath))"

			# check to see if destination folder exists
			if ((Test-Path -Path $([System.IO.Path]::GetDirectoryName($DestinationPath))) -eq $false)
			{
				# Create the folder
				New-Item -Path $([System.IO.Path]::GetDirectoryName($DestinationPath)) -ItemType Directory -Force
			}
			
			# Display what we're copying
			Write-Verbose "Copying $($DriveLetter):\$([System.IO.Path]::GetFileName($SourcePath)) to $DestinationPath"

			# Copy the item using the specified credentials
			Copy-Item -Path "$($DriveLetter):\$([System.IO.Path]::GetFileName($SourcePath))" -Destination $DestinationPath -Force -Recurse

			# Write successful
			Write-Verbose "Successfully copied $SourcePath"

			# Remove the driver
			Remove-PSDrive -Name $DriveLetter

			# Remove drive letter
			Write-Verbose "Successfully removed $DriveLetter"
		}
		else
		{
			Copy-Item -Path $SourcePath -Destination $DestinationPath
		}
	
}

Function Get-UnusedDriverLetter
{
	# Get all used drive letters
	$DriveLetters = Get-PSDrive -PSProvider FileSystem | Select Name

	# Create alphabet array
	$alph=@()

	# Start at C
	67..90|foreach-object{$alph+=[char]$_}

	# Loop through alphabet array
	ForEach ($Letter in $alph)
	{
		# Check to see if the driver letter is in use
		if(($DriveLetters | Where-Object {$_.Name -eq $Letter}) -eq $null)
		{
			return $Letter
		}
	}	
}

function Get-XMLNodeByNamespace
{
    # Define parameters
    Param
    (
        $XmlNode,
        $Namespace
    )

    # Define working variables
    $NodeCollection = @()

    # Check to see if there are child nodes
    if ($XmlNode.ChildNodes)
    {
        # Loop through child nodes
        foreach ($childNode in $XmlNode.ChildNodes)
        {
            # Recurse
            $NodeCollection += Get-XMLNodeByNamespace -XmlNode $childNode -Namespace $Namespace
        }
    }

    # Check the current node namespace
    if ($XmlNode.NamespaceURI -like "*$Namespace*")
    {
        # Add node to collection
        $NodeCollection += $XmlNode
    }

    # Return the collection
    return $NodeCollection
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

        [parameter(Mandatory = $true)]
		[System.String]
		$Slot,

        [parameter(Mandatory = $true)]
        [System.String]
        $ModuleDir,

		[parameter(Mandatory = $true)]
        [System.String]
        $SourceDir,

		[parameter(Mandatory = $true)]
        [System.String]
        $Profile,

		[System.Management.Automation.PSCredential]
        $Credential,

        [parameter(Mandatory = $true)]
        [System.String]
        $ConfigDir,

        [parameter(Mandatory = $true)]
        [System.String]
        $ConfigFile
    )

    # Load xml document
    [xml]$xmlDoc = Get-Content -Path "$ConfigDir\$ConfigFile"

    # Get all the datasource nodes in the specified profile
    $domainProfile = $xmlDoc.GetElementsByTagName("profile") | Where-Object {$_.name -eq $Profile}

	# Get reference to the subsystem node
	$subSystemNode = (Get-XMLNodeByNamespace -XmlNode $domainProfile -Namespace "urn:jboss:domain:ee") | Where-Object {$_.LocalName -eq "subsystem"}

	# Get reference to the global module
	$globalModuleNodes = $subSystemNode.ChildNodes | Where-Object {$_.LocalName -eq "global-modules"}

	# Check to see if global modules is empty
	if ($globalModuleNodes)
	{
		# Get reference to the specific module
		$moduleNode = $globalModuleNodes.ChildNodes | Where-Object {($_.name -eq $Name) -and ($_.slot -eq $Slot)}

		# Check to see if it's empty
		if ($moduleNode)
		{
			$result = @{
				Name = $moduleNode.name
				Slot = $moduleNode.slot
				FolderExists = (Get-ChildItem -Path "$ModuleDir\$Name\$Slot" -eq $null)
			}
		}
		else
		{
			$result = $null
		}
	}
	else
	{
		# Result is null
		$result = $null
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
        $Name,

		[System.String]
		$Ensure,
        
        [parameter(Mandatory = $true)]
		[System.String]
		$Slot,

        [parameter(Mandatory = $true)]
        [System.String]
        $ModuleDir,

		[parameter(Mandatory = $true)]
        [System.String]
        $SourceDir,

		[parameter(Mandatory = $true)]
        [System.String]
        $Profile,

		[System.Management.Automation.PSCredential]
        $Credential,

        [parameter(Mandatory = $true)]
        [System.String]
        $ConfigDir,

        [parameter(Mandatory = $true)]
        [System.String]
        $ConfigFile
    )

    # Load xml document
    [xml]$xmlDoc = Get-Content -Path "$ConfigDir\$ConfigFile"

    # Get all the datasource nodes in the specified profile
    $domainProfile = $xmlDoc.GetElementsByTagName("profile") | Where-Object {$_.name -eq $Profile}

	# Get reference to the subsystem node
	$subSystemNode = (Get-XMLNodeByNamespace -XmlNode $domainProfile -Namespace "urn:jboss:domain:ee") | Where-Object {$_.LocalName -eq "subsystem"}

	# Get reference to the global module
	$globalModuleNodes = $subSystemNode.ChildNodes | Where-Object {$_.LocalName -eq "global-modules"}

    # determine action
    switch($Ensure)
    {
        "Present"
        {
			# Check to see if global modules node exists
			if ($globalModuleNodes -eq $null)
			{ 
				# Create new node
				$globalModuleNodes = $xmlDoc.CreateElement("global-modules", $subSystemNode.NamespaceURI)

				# Attach to subsystem
				$subSystemNode.AppendChild($globalModuleNodes)
			}

			# Get reference to the specific module
			$moduleNode = $globalModuleNodes.ChildNodes | Where-Object {($_.name -eq $Name) -and ($_.slot -eq $Slot)}

			# Check to see if the node exists
			if ($moduleNode -eq $null)
			{
				# Create the module node
				$moduleNode = $xmlDoc.CreateElement("module", $globalModuleNodes.NamespaceURI)

				# Attach to parent
				$globalModuleNodes.AppendChild($moduleNode)
			}

			# Set the attributes
			$moduleNode.SetAttribute("name", $Name)
			$moduleNode.SetAttribute("slot", $Slot)

			# Copy the files from source to destination
			Copy-File -SourcePath $SourceDir -DestinationPath $ModuleDir -Credential $Credential
        }
        "Absent"
        {
			# Get reference to the specific module
			$moduleNode = $globalModuleNodes.ChildNodes | Where-Object {($_.name -eq $Name) -and ($_.slot -eq $Slot)}

			# Check to see if it's there
			if ($moduleNode -ne $null)
			{
				# Remove the module
				$moduleNode.ParentNode.RemoveChild($moduleNode)
			}

			# Verify file exists
			if (Test-Path -Path "$ModuleDir\$Name")
			{
				# Delete the files
				Remove-Item -Path "$ModuleDir\$Name" -Force
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
        
        [parameter(Mandatory = $true)]
		[System.String]
		$Slot,

        [parameter(Mandatory = $true)]
        [System.String]
        $ModuleDir,

		[parameter(Mandatory = $true)]
        [System.String]
        $SourceDir,

		[parameter(Mandatory = $true)]
        [System.String]
        $Profile,

		[System.Management.Automation.PSCredential]
        $Credential,

        [parameter(Mandatory = $true)]
        [System.String]
        $ConfigDir,

        [parameter(Mandatory = $true)]
        [System.String]
        $ConfigFile
    )

	# Declare working variables
	$desiredState = $true

    # Load xml document
    [xml]$xmlDoc = Get-Content -Path "$ConfigDir\$ConfigFile"

    # Get all the datasource nodes in the specified profile
    $domainProfile = $xmlDoc.GetElementsByTagName("profile") | Where-Object {$_.name -eq $Profile}

	# Get reference to the subsystem node
	$subSystemNode = (Get-XMLNodeByNamespace -XmlNode $domainProfile -Namespace "urn:jboss:domain:ee") | Where-Object {$_.LocalName -eq "subsystem"}

	# Get reference to the global module
	$globalModuleNodes = $subSystemNode.ChildNodes | Where-Object {$_.LocalName -eq "global-modules"}

    # determine action
    switch($Ensure)
    {
        "Present"
        {
			# Check to see if global modules is empty
			if ($globalModuleNodes)
			{
				# Get reference to the specific module
				$moduleNode = $globalModuleNodes.ChildNodes | Where-Object {($_.name -eq $Name) -and ($_.slot -eq $Slot)}

				# Check to see if it's empty
				if ($moduleNode -eq $null)
				{
					# Not in desired state
					$desiredState = $false
				}
				else
				{
					# Verify folder exists
					if ((Test-Path -Path "$ModuleDir\$Name\$Slot") -eq $false)
					{
						# Not in desired state
						$desiredState = $false
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
			# Check to see if global modules is empty
			if ($globalModuleNodes)
			{
				# Get reference to the specific module
				$moduleNode = $globalModuleNodes.ChildNodes | Where-Object {($_.name -eq $Name) -and ($_.slot -eq $Slot)}

				# Check to see if it's empty
				if ($moduleNode -ne $null)
				{
					# Not in desired state
					$desiredState = $false

					break
				}

				if ((Get-ChildItem -Path "$ModuleDir\$Name\$Slot") -ne $null)
				{
					# Not in desired state
					$desiredState = $false
				}
			}
        }
    }
	
	    
    if($desiredState)
    {
        Write-Verbose "Wildfly global module $Name - $Slot in desired state, no action required."
    }
    else
    {
        Write-Verbose "Wildfly global module $Name - $Slot is not in desired state."
    }

    return $desiredState
}


Export-ModuleMember -Function *-TargetResource

