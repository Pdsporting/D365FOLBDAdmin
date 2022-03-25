function Get-D365LCSEnvironmentDetailsProjectPage {
    <#
    .SYNOPSIS
    Needs Selenium Powershell running on projects page
   .DESCRIPTION
  
   .EXAMPLE
   
    
   #>
    [alias("Get-LCSEnvironmentDetailsProjectPages")]
    [CmdletBinding()]
    param()
    ##Gather Information from the Dynamics 365 Orchestrator Server Config
    BEGIN {
    } 
    PROCESS {
        $CustomObjectAllEnvironments = @()
        $allenvironments = Get-SeElement -By XPath -Value "//div[contains(text(), 'Environment')]"
        $environmentcount = 0
        foreach ($environmentlcs in $allenvironments) {
            $environmentcount = $environmentcount + 1
            $text = $environmentlcs.text 
            $substring = $text.Substring(12)
            $environmentname = $substring.split('')[0]
            $finalsubstring = $substring -replace 'state:', ''
            $status = $($finalsubstring -replace $environmentname, '').trim('')

            $environmentcustom = New-Object -TypeName psobject -Property `
            @{'EnvironmentName'    = $environmentName
                'EnvironmentState' = $status
                'EnvironmentOrder' = $environmentCount
            }
            $CustomObjectAllEnvironments = $CustomObjectAllEnvironments + $environmentcustom
        }

        $allenvironmentsfulldetails = Get-SeElement -By XPath -Value "//div[contains(text(), 'Environment')]//parent::*//parent::*//parent::*//parent::*//parent::*//*[contains(text(), 'Full details')]"
        $countofsandboxes = Get-SeElement -By XPath -Value "//div[contains(text(), 'Environment')]//parent::*//parent::*//parent::*//parent::*//parent::*//parent::*//parent::*//parent::*//*[contains(text(), 'Sandbox')]"
        if ($allenvironmentsfulldetails.count -ne $countofsandboxes.Count) {
            Write-verbose "Production environment deployed"
            $ProdFound = "yes"
        }
        $CustomObjectAllEnvironmentsurl = @()
        $environmentcount = 0
        foreach ($details in $allenvironmentsfulldetails) {
            $environmentcount = $environmentcount + 1
            $url = Get-SeElementAttribute -Element $details -Name 'href'
            $environmenturlcustom = New-Object -TypeName psobject -Property `
            @{'Environmenturl'     = $url
                'EnvironmentOrder' = $environmentCount
            }
            $CustomObjectAllEnvironmentsurl = $CustomObjectAllEnvironmentsurl + $environmenturlcustom
        }

        $AllEnvironmentsLCS = @()
        foreach ($CustomObject in $CustomObjectAllEnvironments) {
            $Counter = $CustomObject.EnvironmentOrder
            if ($Counter -eq 1 -and $ProdFound -eq "yes") {
                $EnvironmentType = 'Production'
            }
            else {
                $EnvironmentType = 'Sandbox'
            }
            $URL = $CustomObjectAllEnvironmentsurl | Where-Object { $_.EnvironmentOrder -eq $Counter }
            $environmenturlcustom = New-Object -TypeName psobject -Property `
            @{'EnvironmentName'    = $CustomObject.environmentName
                'EnvironmentState' = $CustomObject.EnvironmentState
                'EnvironmentOrder' = $CustomObject.EnvironmentOrder
                'EnvironmentType'  = $EnvironmentType
                'EnvironmentURL'   = $URL.Environmenturl
            }
            $AllEnvironmentsLCS = $AllEnvironmentsLCS + $environmenturlcustom

        }
        $AllEnvironmentsLCS
    }
    END {}
}