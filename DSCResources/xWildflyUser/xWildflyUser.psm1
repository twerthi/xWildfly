function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $UserName,

        [parameter(Mandatory = $true)]
        [System.String]
        $Type,

        [System.Management.Automation.PSCredential]
        $Credential,

		[System.String]
		$ConfigDir,

		[System.String]
		$BinDir
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

	# Declare working variables
	$wildflyUsers = @()
	$users = @()
	$result = @{}

	switch($Type)
	{
		"Management"
		{
			$wildflyUsers = @(Get-Content "$ConfigDir\mgmt-users.properties" | Where-Object {!$_.StartsWith("#")})	
		}
		"Application"
		{
			$wildflyUsers = @(Get-Content "$ConfigDir\application-users.properties" | Where-Object {!$_.StartsWith("#")})
		}
	}
    
	# Loop through file contents
    ForEach ($user in $wildflyUsers)
    {
        $users += $user.Split("=")[0]
    }

    # return the results
    $result["Users"] = $users
    return $result
}


function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure,

        [parameter(Mandatory = $true)]
        [System.String]
        $UserName,

        [parameter(Mandatory = $true)]
        [System.String]
        $Type,

        [System.Management.Automation.PSCredential]
        $Credential,

		[System.String]
		$ConfigDir,

		[System.String]
		$BinDir
    )

    #Write-Verbose "Use this cmdlet to deliver information about command processing."

    #Write-Debug "Use this cmdlet to write debug information while troubleshooting."

    #Include this line if the resource requires a system reboot.
    #$global:DSCMachineStatus = 1

    switch($Ensure)
    {
        "Present"
        {
            # Determine type
            switch($Type)
            {
                "Management"
                {
                    # Display
                    Write-Verbose "Adding $UserName to Management users"
                    
                    # Add user to wildfly
                    Start-Process -FilePath "$BinDir\add-user.bat" -ArgumentList "$UserName $($Credential.GetNetworkCredential().Password)"
                }
                "Application"
                {
                    # Display
                    Write-Verbose "Adding $UserName to Application users"

                    # Add user to wildfly
                    Start-Process -FilePath "$BinDir\add-user.bat" -ArgumentList "-a $UserName $($Credential.GetNetworkCredential().Password)"
                }
            }
                                    
        }
        "Absent"
        {
                                    
            # Determine type
            switch($Type)
            {
                "Management"
                {
                    # Display
                    Write-Verbose "Removing $UserName from Management users"
                    
                    # get the contents of the file
                    $adminFile = Get-Content "$ConfigDir\mgmt-users.properties" | Where-Object {!$_.StartsWith($UserName)}

                    # save the file without the user in it
                    Set-Content "$ConfigDir\mgmt-users.properties" $adminFile
                }
                "Application"
                {
                    # Display
                    Write-Verbose "Removing $UserName from Application users"

                    # get the contents of the file
                    $adminFile = Get-Content "$ConfigDir\application-users.properties" | Where-Object {!$_.StartsWith($UserName)}

                    # save the file without the user in it
                    Set-Content "$ConfigDir\application-users.properties" $adminFile
                }
            }
        }
    }
}


function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure,

        [parameter(Mandatory = $true)]
        [System.String]
        $UserName,

        [parameter(Mandatory = $true)]
        [System.String]
        $Type,

        [System.Management.Automation.PSCredential]
        $Credential,

		[System.String]
		$ConfigDir,

		[System.String]
		$BinDir
    )

    #Write-Verbose "Use this cmdlet to deliver information about command processing."

    #Write-Debug "Use this cmdlet to write debug information while troubleshooting."


    <#
    $result = [System.Boolean]
    
    $result
    #>

	# Declare working variables
	$wildflyUsers = @()
	$users = @()
                                                        
	# determine type
	switch($Type)
	{
		"Management"
		{
			$wildflyUsers = @(Get-Content "$ConfigDir\mgmt-users.properties" | Where-Object {!$_.StartsWith("#")})
		}
		"Application"
		{
			$wildflyUsers = @(Get-Content "$ConfigDir\application-users.properties" | Where-Object {!$_.StartsWith("#")})
		}
	}


	# Loop through file contents
	ForEach ($user in $wildflyUsers)
	{
		$users += $user.Split("=")[0]
	}

	# Check Ensure property
	switch($Ensure)
	{
		"Present"
		{
			# Check the collection for the current user
			if ($users.Contains($UserName))
			{
				# Display
                Write-Verbose "$UserName in desired state, no action required"
                
                # doesn't need to run
				return $true
			}
			else
			{
				# Display
                Write-Verbose "$UserName not in desired state"

                # Needs to run
				return $false
			}
		}
		"Absent"
		{
			# Check the collection for the current user
			if ($users.Contains($UserName))
			{
				# Display
                Write-Verbose "$UserName not in desired state"

                # Needs to run
				return $false
			}
			else
			{
                # Display				
                Write-Verbose "$UserName in desired state, no action required"

                # Doesn't needs to run
				return $true
			}
		}
	}
}


Export-ModuleMember -Function *-TargetResource

