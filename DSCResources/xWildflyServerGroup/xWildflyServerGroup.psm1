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
        $Profile,

        [System.String]
        $JvmHeapSize,

        [System.String]
        $JvmMaxHeapSize,

        [Parameter()]
        $JvmOptions,

        [System.String]
        $SocketBindingGroup,

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

    # Load xml document
    [xml]$xmlDoc = Get-Content -Path "$ConfigDir\$ConfigFile"

    # Get all the datasource nodes in the specified profile
    $serverGroup = $xmlDoc.GetElementsByTagName("server-group") | Where-Object {($_.name -eq $Name)}

    # Save the results
    $result = @{
        Name = $serverGroup.Name
        Profile = $serverGroup.Profile
        Jvm = $serverGroup.Jvm
        SocketBindingGroup = $serverGroup.'socket-binding-group'
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
        $Profile,

        [System.String]
        $JvmHeapSize,

        [System.String]
        $JvmMaxHeapSize,

        [Parameter()]
        $JvmOptions,

        [System.String]
        $SocketBindingGroup,

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

    # Get all the datasource nodes in the specified profile
    $serverGroup = $xmlDoc.GetElementsByTagName("server-group") | Where-Object {($_.name -eq $Name)}
    $serverGroups = $xmlDoc.GetElementsByTagName("server-groups")

    switch($Ensure)
    {
        "Present"
        {
            # Check for the existance of the datasource
            if ($serverGroup -ne $null)
            {
                # Display 
                Write-Verbose "Updating server group $Name"
             
                # Update the server group properties -- I think this needs refactoring
                $serverGroup.'socket-binding-group'.ref = $SocketBindingGroup
                $serverGroup.jvm.heap.size = $JvmHeapSize
                $serverGroup.jvm.heap.'max-size' = $JvmMaxHeapSize
                $serverGroup.profile = $Profile

                # Get reference to options node
                $groupJvmOptions = $serverGroup.jvm.'jvm-options'

                # Check for null
                if ($groupJvmOptions -ne $null)
                {
                    # Remove all nodes
                    $serverGroup.jvm.RemoveChild($groupJvmOptions)
                }
                
                # Check to see if there are options to set
                if ($JvmOptions -ne $null)
                {
                    # Create new options node
                    $groupJvmOptions = $xmlDoc.CreateElement("jvm-options", $serverGroup.NamespaceURI)

                    # Loop through the options
                    ForEach ($option in $JvmOptions)
                    {
                        # Create new option node
                        $groupOption = $xmlDoc.CreateElement("option", $serverGroup.NamespaceURI)

                        # Set value attribute
                        $groupOption.SetAttribute("value", $option)

                        # Append to node
                        $groupJvmOptions.AppendChild($groupOption)
                    }

                    # Append to server group jvm
                    $serverGroup.jvm.AppendChild($groupJvmOptions)
                }                
            }
            else
            {
                # Display
                Write-Verbose "Creating server group $Name"
                
                # Create new Datasource entry
                $serverGroup = $xmlDoc.CreateElement("server-group", $serverGroups.NamespaceURI)

                # Fill in the server group node attributes
                $serverGroup.SetAttribute("name", $Name)
                $serverGroup.SetAttribute("profile", $Profile)

                # Create jvm subnode
                $jvmNode = $xmlDoc.CreateElement("jvm", $serverGroups.NamespaceURI)
                $jvmNode.SetAttribute("name", "default")

                # Create jvm heap node
                $jvmHeapNode = $xmlDoc.CreateElement("heap", $serverGroups.NamespaceURI)
                $jvmHeapNode.SetAttribute("max-size", $JvmMaxHeapSize)
                $jvmHeapNode.SetAttribute("size", $JvmHeapSize)

                # Create socket binding group node
                $socketBindingGroupNode = $xmlDoc.CreateElement("socket-binding-group", $serverGroups.NamespaceURI)
                $socketBindingGroupNode.SetAttribute("ref", $SocketBindingGroup)

                # Append child nodes
                $jvmNode.AppendChild($jvmHeapNode)
                
                $serverGroup.AppendChild($jvmNode)
                $serverGroup.AppendChild($socketBindingGroupNode)
                $serverGroup.Attributes.RemoveNamedItem("xmlns")
                
                $serverGroups.AppendChild($serverGroup)
            }
        }
        "Absent"
        {
            # Display
            Write-Verbose "Removing server group $Name"
            
            $serverGroup.ParentNode.RemoveChild($serverGroup)
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

        [System.String]
        $Profile,

        [System.String]
        $JvmHeapSize,

        [System.String]
        $JvmMaxHeapSize,

        [Parameter()]
        $JvmOptions,

        [System.String]
        $SocketBindingGroup,

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
    $desiredState = $true

    # Load xml document
    [xml]$xmlDoc = Get-Content -Path "$ConfigDir\$ConfigFile"

    # Get all the datasource nodes in the specified profile
    $serverGroup = $xmlDoc.GetElementsByTagName("server-group") | Where-Object {($_.name -eq $Name)}

    switch($Ensure)
    {
        "Present"
        {
            # Check for the existance of the datasource
            if ($serverGroup -ne $null)
            {
                # Test the specific properties
                if ($serverGroup.'socket-binding-group'.ref -ne $SocketBindingGroup)
                {
                    # not in desired state
                    $desiredState = $false

                    # Break from if
                    break
                }

                if ($serverGroup.jvm.heap.size -ne $JvmHeapSize)
                {
                    # Not in desired state
                    $desiredState = $false

                    break
                }

                if ($serverGroup.jvm.heap.'max-size' -ne $JvmMaxHeapSize)
                {
                    # Not in desired state
                    $desiredState = $false

                    break
                }

                if (($serverGroup.jvm.'jvm-options' -ne $null) -and ($JvmOptions -ne $null))
                {
                    # Check node count
                    if ($serverGroup.jvm.'jvm-options'.option.Count -ne $JvmOptions.Count)
                    {
                        # Not in desired state
                        $desiredState = $false
                    }
                    else
                    {
                        # Loop through options and compare
                        ForEach($option in $JvmOptions)
                        {
                            # Compare to value
                            if (($serverGroup.jvm.'jvm-options'.option | Where-Object {$_.value -eq $option}) -eq $null)
                            {
                                # Not in desired state
                                $desiredState = $false
                                
                                # Loop no longer needed
                                break
                            }
                        }
                    }
                }
                elseif (($serverGroup.jvm.'jvm-options' -eq $null) -and ($JvmOptions -ne $null))
                {
                    # Not in desired state
                    $desiredState = $false
                }
                elseif (($serverGroup.jvm.'jvm-options' -ne $null) -and ($JvmOptions -eq $null))
                {
                    # Not in desired state
                    $desiredState = $false
                }
                

                if ($serverGroup.profile -ne $Profile)
                {
                    # Not in desired state
                    $desiredState = $false
                    
                    break    
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
            if ($serverGroup -ne $null)
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
        Write-Verbose "Server group $Name is in desired state, no action required"
        
        # return result
        return $true
    }
    else
    {
        # Display
        Write-Verbose "Server group $Name is not in desired state"

        # return result
        return $false
    }
}

 
Export-ModuleMember -Function *-TargetResource

