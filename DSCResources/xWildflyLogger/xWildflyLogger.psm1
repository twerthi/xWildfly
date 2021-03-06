function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Category,

		[System.String]
		$Ensure,
        
		[System.String]
		$LevelName,

        [parameter(Mandatory = $true)]
        [System.String]
        $ConfigDir,

		[parameter(Mandatory = $true)]
        [System.String]
        $ConfigFile,

		[parameter(Mandatory = $true)]
        [System.String]
        $Profile
    )

    # Load xml document
    [xml]$xmlDoc = Get-Content -Path "$ConfigDir\$ConfigFile"

    # Get all the datasource nodes in the specified profile
    $domainProfile = $xmlDoc.GetElementsByTagName("profile") | Where-Object {$_.name -eq $Profile}

	# Get all of the logging profiles
	$loggingNodes = $domainProfile.GetElementsByTagName("logger")

	# Get the specific logging category
	$loggingNode = $loggingNodes | Where-Object {$_.category -eq $Category}

	# Send back the result
	$result = @{
		Category = $Category
		Level = $loggingNode.level
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
        $Category,

		[System.String]
		$Ensure,
        
		[System.String]
		$LevelName,

        [parameter(Mandatory = $true)]
        [System.String]
        $ConfigDir,

		[parameter(Mandatory = $true)]
        [System.String]
        $ConfigFile,

		[parameter(Mandatory = $true)]
        [System.String]
        $Profile
    )

    # Load xml document
    [xml]$xmlDoc = Get-Content -Path "$ConfigDir\$ConfigFile"

    # Get all the datasource nodes in the specified profile
    $domainProfile = $xmlDoc.GetElementsByTagName("profile") | Where-Object {$_.name -eq $Profile}

	# Get all of the logging profiles
	$loggingNodes = $domainProfile.GetElementsByTagName("logger")

	# Get parentnode
	$loggingParentNode = $loggingNodes[0].ParentNode

	# Get the specific logging category
	$loggingNode = $loggingNodes | Where-Object {$_.category -eq $Category}

    # determine action
    switch($Ensure)
    {
        "Present"
        {
			# Check to see if category is present
			if ($loggingNode -eq $null)
			{
				# Display
				Write-Verbose "Creating new logger node."
			
				# Create new node
				$loggingNode = $xmlDoc.CreateElement("logger", $loggingParentNode.NamespaceURI)

				# Display
				Write-Verbose "Setting category attribute to $Category."
				
				# Set the category attribute
				$loggingNode.SetAttribute("category", $Category)

				# Display
				Write-Verbose "Creating level node."

				# Create level node
				$levelNode = $xmlDoc.CreateElement("level", $loggingParentNode.NamespaceURI)

				# Display
				Write-Verbose "Setting name attribute on level node to: $LevelName."

				# Set name attribute
				$levelNode.SetAttribute("name", $LevelName)

				# Display
				Write-Verbose "Attaching level node to logger node."
				
				# Attach level to logging
				$loggingNode.AppendChild($levelNode)

				# Display
				Write-Verbose "Attaching logger node to nodes collection."

				# Attach loggingNode to nodes
				$loggingParentNode.AppendChild($loggingNode)
			}
			else
			{
				# Get reference to the level node
				$levelNode = $loggingNode.ChildNodes | Where-Object {$_.LocalName -eq "level"}

				# Check to see if null
				if ($levelNode -eq $null)
				{
					# Create the level node
					$levelNode = $xmlDoc.CreateElement("level", $loggingNode.NamespaceURI)

					# Attach to parent
					$loggingNode.AppendChild($levelNode)
				}

				# Set the name attribute
				$levelNode.SetAttribute("name", $LevelName)
			}
        }
        "Absent"
        {
			# Check to see if is null
			if ($loggingNode -ne $null)
			{
				# Remove the node
				$loggingNode.ParentNode.RemoveChild($loggingNode)
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
        $Category,

		[System.String]
		$Ensure,
        
		[System.String]
		$LevelName,

        [parameter(Mandatory = $true)]
        [System.String]
        $ConfigDir,

		[parameter(Mandatory = $true)]
        [System.String]
        $ConfigFile,

		[parameter(Mandatory = $true)]
        [System.String]
        $Profile
    )

	# Declare working variables
	$desiredState = $true

    # Load xml document
    [xml]$xmlDoc = Get-Content -Path "$ConfigDir\$ConfigFile"

    # Get all the datasource nodes in the specified profile
    $domainProfile = $xmlDoc.GetElementsByTagName("profile") | Where-Object {$_.name -eq $Profile}

	# Get all of the logging profiles
	$loggingNodes = $domainProfile.GetElementsByTagName("logger")

	# Get the specific logging category
	$loggingNode = $loggingNodes | Where-Object {$_.category -eq $Category}

    # determine action
    switch($Ensure)
    {
        "Present"
        {
			# Check to see if category is present
			if ($loggingNode -eq $null)
			{
				# Not in desired state
				$desiredState = $false
			}
			else
			{
				# Get reference to the level node
				$levelNode = $loggingNodes.ChildNodes | Where-Object {$_.Name -eq "level"}

				# Check to see if level node is present
				if ($levelNode -eq $null)
				{
					# Not in desired state
					$desiredState = $false
				}
				# Compare value
				elseif ($levelNode.GetAttribute("name") -ne $LevelName)
				{
					# Not in desired state
					$desiredState = $false
				}
			}
        }
        "Absent"
        {
			# Check to see if category is present
			if ($loggingNode -ne $null)
			{
				# Not in desired state
				$desiredState = $false
			}
        }
    }
	
	    
    if($desiredState)
    {
        Write-Verbose "Wildfly logger in desired state, no action required."
    }
    else
    {
        Write-Verbose "Wildfly logger is not in desired state."
    }

    return $desiredState
}


Export-ModuleMember -Function *-TargetResource

