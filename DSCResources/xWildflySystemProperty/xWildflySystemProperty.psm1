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
		$Value,

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

	# Open the xml file
	[xml]$xmlDoc = Get-Content -Path "$ConfigDir\$ConfigFile"

	# Get reference to the server-properties node
	$systemProperties = $xmlDoc.GetElementsByTagName("system-properties")
	$result = @()

	# Loop through the returned values
	$systemProperties | ForEach-Object {$result += @{name = $_.Name
	value = $_.value}}

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
		$Value,

		[System.String]
		$ConfigFile,

		[System.String]
		$ConfigDir    )

    #Write-Verbose "Use this cmdlet to deliver information about command processing."

    #Write-Debug "Use this cmdlet to write debug information while troubleshooting."

    #Include this line if the resource requires a system reboot.
    #$global:DSCMachineStatus = 1

	# Open the xml file
	[xml]$xmlDoc = Get-Content -Path "$ConfigDir\$ConfigFile"

	# Get reference to the server-properties node
	$systemProperties = $xmlDoc.GetElementsByTagName("system-properties")

	# Get reference to specific property
	$systemProperty = $systemProperties.ChildNodes | Where-Object {$_.Name -eq $Name}

	# Check ensure value
	switch ($Ensure)
	{
		"Present"
		{
			# Check to see if systemproperties is null
			if ([string]::IsNullOrEmpty($systemProperties))
			{
				# Create the system-properties node
				$systemProperties = $xmlDoc.CreateElement("system-properties", $xmlDoc.DocumentElement.NamespaceURI)

				# Find the extensions node
				$extensionsNode = $xmlDoc.DocumentElement.ChildNodes | Where-Object {$_.LocalName -eq "extensions"}

				# Add to xml document
				$xmlDoc.DocumentElement.InsertAfter($systemProperties, $extensionsNode)
			}
		
			# Check for null
			if ($systemProperty -eq $null)
			{
				# Create the node
				$systemProperty = $xmlDoc.CreateElement("property", $systemProperties.NamespaceURI)

				# Set the name attribute
				$systemProperty.SetAttribute("name", $Name)

				# Add to properties
				$systemProperties.AppendChild($systemProperty)
			}

			# Set the value attribute
			$systemProperty.SetAttribute("value", $Value)
		}
		"Absent"
		{
			# Check for value
			if ($systemProperty)
			{
				# Remove node
				$systemProperties.RemoveChild($systemProperty)
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
		$Value,

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

	[xml]$xmlDoc = Get-Content -Path "$ConfigDir\$ConfigFile"

	# Get reference to the server-properties node
	$systemProperties = $xmlDoc.GetElementsByTagName("system-properties")

	# Get reference to specific property
	$systemProperty = $systemProperties.ChildNodes | Where-Object {$_.Name -eq $Name}

    switch($Ensure)
    {
        "Present"
        {
			# Check to see if node is null
			if ($systemProperty)
			{
				# Check attribute value
				if ($systemProperty.GetAttribute("value") -ne $Value)
				{
					# Not in desired state
					$desiredState = $false
					break
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
			# Check for null
			if ($systemProperty)
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
        Write-Verbose "System property $Name is in desired state, no action required"
        
        # return result
        return $true
    }
    else
    {
        # Display
        Write-Verbose "System property $Name is not in desired state"

        # return result
        return $false
    }
}

 
Export-ModuleMember -Function *-TargetResource

