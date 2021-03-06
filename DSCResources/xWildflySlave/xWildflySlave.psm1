function Get-EncodedSecret
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

        [System.Management.Automation.PSCredential]
        $Credential,

        [parameter(Mandatory = $true)]
        [System.String]
        $DomainController,

        [parameter(Mandatory = $true)]
        [System.String]
        $DomainControllerPort,

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
	$result = @{}

    # Load xml document
    [xml]$xmlDoc = Get-Content -Path "$ConfigDir\$ConfigFile"

    # Get management realm
    $managementRealm = $xmlDoc.GetElementsByTagName("security-realm") | Where-Object {$_.name -eq "ManagementRealm"}

    # Get domain controller
    $domainControllerNode = $xmlDoc.GetElementsByTagName("domain-controller")

    # return the results
    $result["DomainController"] = $(if($domainControllerNode.local) {"Local"} else {$domainControllerNode.remote.host})
    $result["ServerIdentities"] = $(if($managementReal.'server-identities') {$true} else {$false})


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

        [System.Management.Automation.PSCredential]
        $Credential,

        [parameter(Mandatory = $true)]
        [System.String]
        $DomainController,

        [parameter(Mandatory = $true)]
        [System.String]
        $DomainControllerPort,

		[System.String]
		$ConfigDir,

		[System.String]
		$ConfigFile
    )

    #Write-Verbose "Use this cmdlet to deliver information about command processing."

    #Write-Debug "Use this cmdlet to write debug information while troubleshooting."

    #Include this line if the resource requires a system reboot.
    #$global:DSCMachineStatus = 1

    # Load xml document
    [xml]$xmlDoc = Get-Content -Path "$ConfigDir\$ConfigFile"

    # Get management realm
    $managementRealm = $xmlDoc.GetElementsByTagName("security-realm") | Where-Object {$_.name -eq "ManagementRealm"}

    # Get domain controller
    $domainControllerNode = $xmlDoc.GetElementsByTagName("domain-controller")


    switch($Ensure)
    {
        "Present"
        {
            # Check for local node
            if ($domainControllerNode.local -ne $null)
            {
                Write-Warning "1"
                # Remove node
                $localNode = $domainControllerNode.ChildNodes | Where-Object {$_.Name -eq "local"}
                $localNode.ParentNode.RemoveChild($localNode)

                # Create remote node
                $remoteNode = $xmlDoc.CreateElement("remote", $domainControllerNode.NamespaceURI)

                # Fill in attributes
                $remoteNode.SetAttribute("security-realm", "ManagementRealm")
                $remoteNode.SetAttribute("port", $DomainControllerPort)
                $remoteNode.SetAttribute("username", $Credential.UserName)
                $remoteNode.SetAttribute("host", $DomainController)

                # Add new node
                $domainControllerNode.AppendChild($remoteNode)
            }
            else
            {
                Write-Warning "2"
                # Get reference to remote node
                $remoteNode = $domainControllerNode.ChildNodes | Where-Object {$_.Name -eq "remote"}

                # Update attributes
                $remoteNode.port = $DomainControllerPort
                $remoteNode.username = $Credential.UserName
                $remoteNode.host = $DomainController
            }

            # Check for local authentication
            if ($managementRealm.authentication.local -ne $null)
            {
                Write-Warning "3"
                # Remove the node
                $localNode = $managementRealm.authentication.local
                $localNode.ParentNode.RemoveChild($localNode)

                # Create new nodes
                $serverIdentities = $xmlDoc.CreateElement("server-identities", $managementRealm.NamespaceURI)
                $secret = $xmlDoc.CreateElement("secret", $managementRealm.NamespaceURI)

                # Set the attribute
                $secret.SetAttribute("value", (Get-EncodedSecret -Password $Credential.GetNetworkCredential().Password))

                # Append nodes
                $serverIdentities.AppendChild($secret)
                $managementRealm.AppendChild($serverIdentities)
            }
            else
            {
                Write-Warning "4"
                # Set the secret value
                $serverIdentities = $managementRealm.'server-identities'
                $serverIdentities.secret.value = (Get-EncodedSecret -Password $Credential.GetNetworkCredential().Password)
            }
        }
        "Absent"
        {
            # Check for remote node
            if ($domainControllerNode.remote)
            {
                # Remove the node
                $remoteNode = $domainControllerNode.remote
                $remoteNode.ParentNode.RemoveChild($remoteNode)

                # Create new local node
                $localNode = $xmlDoc.CreateElement("local", $domainControllerNode.NamespaceURI)

                # Add new node
                $domainController.AppendChild($localNode)
            }                        
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

        [System.String]
        $Ensure,

        [System.Management.Automation.PSCredential]
        $Credential,

        [parameter(Mandatory = $true)]
        [System.String]
        $DomainController,

        [parameter(Mandatory = $true)]
        [System.String]
        $DomainControllerPort,

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

    # Load xml document
    [xml]$xmlDoc = Get-Content -Path "$ConfigDir\$ConfigFile"

    # Get management realm
    $managementRealm = $xmlDoc.GetElementsByTagName("security-realm") | Where-Object {$_.name -eq "ManagementRealm"}

    # Get domain controller
    $domainControllerNode = $xmlDoc.GetElementsByTagName("domain-controller")

    $desiredState = $true
                                                        
	# Check Ensure property
	switch($Ensure)
	{
		"Present"
		{
			# Check to make sure it's not local
            if ($domainControllerNode.local)
            {
                # Not in desired state
                $desiredState = $false
            }
            else
            {
                # Check attribute values
                if ($domainControllerNode.port -ne $DomainControllerPort)
                {
                    # Not in desired state
                    $desiredState = $false

                    # No need to continue
                    break
                }

                if ($domainControllerNode.username -ne $Credential.UserName)
                {
                    # Not in desired state
                    $desiredState = $false

                    # No need to continue
                    break
                }

                if ($domainControllerNode.host -ne $DomainController)
                {
                    # Not in desired state
                    $desiredState = $false

                    # No need to continue
                    break
                }
            }
		}
		"Absent"
		{
            if (!$domainControllerNode.local)
            {
                # Not in desired state
                $desiredState = $false
            }
		}
	}

    # Check desired state
    if($desiredState)
    {
        # Display
        Write-Verbose "$Name slave in desired state, no action required."
    }
    else
    {
        Write-Verbose "$Name slave not in desired state."
    }

    # return result
    return $desiredState
}


Export-ModuleMember -Function *-TargetResource

