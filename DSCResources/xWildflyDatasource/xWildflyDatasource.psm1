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

        [System.String]
        $Ensure,

        [System.String]
        $JNDIName,

        [System.String]
        $DriverName,

#        [System.String]
#        $DriverModuleName,

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
                $dataSource.'jndi-name' = $JNDIName
                $dataSource.'connection-url' = $ConnectionUrl
                $dataSource.'driver-class' = $DriverClass
                $dataSource.driver = $DriverName                
                $dataSource.security.'user-name' = $Credential.UserName
                $dataSource.security.password = $Credential.GetNetworkCredential().Password
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
                #$dataSource.Attributes.Remove("xmlns")
                
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
                $securityUserName = $xmlDoc.CreateElement("user-name", $dataSourcesNode.NamespaceURI)
                $securityPassword = $xmlDoc.CreateElement("password", $dataSourcesNode.NamespaceURI)
                $securityUserName.InnerText = $Credential.UserName
                $securityPassword.InnerText = $Credential.GetNetworkCredential().Password
                $dataSourceSecurity.AppendChild($securityUserName)
                $dataSourceSecurity.AppendChild($securityPassword)
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

        [System.String]
        $Ensure,

        [System.String]
        $JNDIName,

        [System.String]
        $DriverName,

#        [System.String]
#        $DriverModuleName,

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

                if ($dataSource.'driver-class' -ne $DriverClass)
                {
                    # Not in desired state
                    $desiredState = $false

                    break
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

