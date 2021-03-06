function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [parameter(Mandatory = $true)]
        [System.String]
        $Ensure,

		[System.String]
		$ConfigDir,

		[System.String]
		$ConfigFile
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
    [xml] $xmlDoc = Get-Content -Path "$ConfigDir\$ConfigFile"

    # Get hode
    $hostNode = $xmlDoc.GetElementsByTagName("host")

    # Set result
    $result = @{ Name = $hostNode.name}

    # Return result
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
        $Name,

		[System.String]
		$ConfigDir,

		[System.String]
		$ConfigFile
    )

    #Write-Verbose "Use this cmdlet to deliver information about command processing."

    #Write-Debug "Use this cmdlet to write debug information while troubleshooting."

    #Include this line if the resource requires a system reboot.
    #$global:DSCMachineStatus = 1

 	# Declare working variables
    [xml] $xmlDoc = Get-Content -Path "$ConfigDir\$ConfigFile"

    # Get hode
    $hostNode = $xmlDoc.GetElementsByTagName("host")
 
    switch($Ensure)
    {
        "Present"
        {
            $hostNode[0].name = $Name    
        }
        "Absent"
        {
            # kind of a misnomer, can't really be absent, so we'll set it back to default
            $hostNode.name = "master"  
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

        [parameter(Mandatory = $true)]
        [System.String]
        $Ensure,

		[System.String]
		$ConfigDir,

		[System.String]
		$ConfigFile
    )

    #Write-Verbose "Use this cmdlet to deliver information about command processing."

    #Write-Debug "Use this cmdlet to write debug information while troubleshooting."


    <#
    $result = [System.Boolean]
    
    $result
    #>

 	# Declare working variables
    [xml] $xmlDoc = Get-Content -Path "$ConfigDir\$ConfigFile"

    # Get hode
    $hostNode = $xmlDoc.GetElementsByTagName("host")

    # Check ensure
    switch ($Ensure)
    {
        "Present"
        {
            if ($hostNode.name -ne $Name)
            {
                return $false
            }
        }

        "Absent"
        {
            if ($hostNode.name -ne "master")
            {
                return $false
            }
        }
    }

    return $true
}


Export-ModuleMember -Function *-TargetResource

