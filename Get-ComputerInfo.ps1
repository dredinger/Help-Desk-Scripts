function Get-ComputerInfo {

    param(
        [Parameter (Mandatory=$false)]
        $cname,

        $NetworkDomain = "",

        $UserAdminPrefix = "",
        $UserAdminSuffix = "",

        $ErrorLog = "c:\Users\$env:USERNAME\Desktop\PSPCInfoErrors.log",
        
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty
    )

    $LoggedOnUser = $UserAdminPrefix
    $LoggedOnUser += $env:USERNAME
    $LoggedOnUser += $UserAdminSuffix

    Write-Host
    Write-Host "=======================================================" -ForegroundColor White
    Write-Host "          -- | PC Info Retrieval Script | -- " -ForegroundColor Yellow
    Write-Host "=======================================================" -ForegroundColor White
    Write-Host

    $ComputerName = $cname

    if ([string]::IsNullOrWhitespace($cname)) {
        $ComputerName = Read-Host "Computer PCID"
    }

    if ([string]::IsNullOrWhitespace($ComputerName)) {
        $ComputerName = $env:COMPUTERNAME
    }

    Write-Host " - Testing PC connection for [" -NoNewLine
    Write-Host "$ComputerName" -ForegroundColor Magenta -NoNewLine
    Write-Host "]: " -NoNewline
    if (Test-Connection -ComputerName $ComputerName -BufferSize 16 -Count 2 -Quiet) {
        $IP = Test-Connection -ComputerName $ComputerName -Count 1 | Select IPV4Address
        Write-Host "online" -ForegroundColor Green
        Write-Host " - Login with admin credentials to view PC info . . ."
        $Creds = Get-Credential -Message "Login with your admin credentials to run this script." -UserName "$NetworkDomain\$LoggedOnUser"
    } else {
        Write-Host "offline" -ForegroundColor Red
        $ComputerName = $NULL
        Read-Host "Press any key to retry..."
        Clear-Host
        Get-ComputerInfo
    }

    try {
        $Splatting = @{
            ComputerName = $ComputerName
            Credential = $Creds
        }

        # Import ActiveDirectory module
        if (!(Get-Module "ActiveDirectory")) {
            Import-Module ActiveDirectory 
        }

        $Everything_is_OK = $true

        # Query OperatingSystem class
        $OperatingSystem = Get-WmiObject -Class Win32_OperatingSystem @Splatting -ErrorAction Stop -ErrorVariable ProcessError
        $LastBoot = $OperatingSystem.ConvertToDateTime($OperatingSystem.LastBootUpTime)
        $Uptime = [DateTime]::Now - $LastBoot
        $Days = $Uptime.days
        $Hours = $Uptime.hours
        $Minutes = $Uptime.minutes
        $Uptime = "$Days day(s), $Hours hour(s), $Minutes minute(s)"

        # Query OU
        $OU = $(Get-ADComputer $ComputerName -Properties CanonicalName).CanonicalName

        # Query ComputerSystem class
        $ComputerSystem = Get-WmiObject -Class win32_ComputerSystem @Splatting -ErrorAction Stop -ErrorVariable ProcessError
        $LoggedUserName = $ComputerSystem.UserName
        if ($LoggedUserName -ne $NULL) {
            $LoggedUserSplit = $LoggedUserName.Split("\")
            $LoggedUserSplit1 = $LoggedUserSplit[1]
        } else {
            $LoggedUserSplit1 = "NONE"
        }

        # Determine TC or PC
        $ComputerType = "TC"
        $ADName = "TC"
        $ADJobTitle = "Kiosk"
        if ($ComputerName.substring(0, 2).ToLower() -ne "tc") {
            $ComputerType = "PC"
            if ($LoggedUserName -ne $NULL) {
                $ADUser = Get-ADUser -Identity $LoggedUserSplit1 -Properties *
                $ADName = $ADUser.CN
                $ADJobTitle = $ADUser.Description
            } else {
                $ADName = "NONE"
                $ADJobTitle = "NONE"
            }
        }

        # Query NetworkAdapterConfiguration class
        $NetworkAdapter = Get-WmiObject -Class win32_NetworkAdapterConfiguration @Splatting -ErrorAction Stop -ErrorVariable ProcessError
        if ($NetworkAdapter.dhcpenabled) {
            $DHCP = "DHCP Enabled"
        } else {
            $DHCP = "Static IP"
        }

        # Query Group class
        $Groups = Get-WmiObject -Class win32_Group @Splatting -Filter "LocalAccount=True AND SID='S-1-5-32-544'" -ErrorAction Stop -ErrorVariable ProcessError
        $GroupsQuery = "GroupComponent = `"Win32_Group.Domain='$($Groups.domain)'`,Name='$($Groups.name)'`""
        
        # Query GroupUser class
        $LocalAdmins = Get-WmiObject -Class win32_GroupUser @Splatting -Filter $GroupsQuery | %{$_.PartComponent} | % {$_.substring($_.lastindexof("Domain=") + 7).replace("`",Name=`"","\")} -ErrorAction Stop -ErrorVariable ProcessError

        # Query Processor class
        $Processors = Get-WmiObject -Class win32_Processor @Splatting -ErrorAction Stop -ErrorVariable ProcessError

        # Count cores
        $Cores = 0
        $Sockets = 0
        foreach ($Proc in $Processors) {
            if ($null -eq $Proc.numberofcores) {
                if ($null -ne $Proc.SocketDesignation) { $Sockets++ }
                $Cores++
            } else {
                $Sockets++
                $Cores += $proc.numberofcores
            }
        }
    }
    catch {
        $Everything_is_OK = $false
        Write-Warning -Message "Error on $ComputerName"
        $ComputerName | Out-File -FilePath $ErrorLog -Append -ErrorAction Continue
        $ProcessError | Out-File -FilePath $ErrorLog -Append -ErrorAction Continue
        Write-Warning -Message "Logged in $ErrorLog"
    }


    if ($Everything_is_OK) {
        # Build output
        $Info = [ordered]@{
            "ComputerName"       = $OperatingSystem.__Server;
            "DHCP Info"          = $DHCP;
            "IP"                 = $IP.IPV4Address;
            "OSName"             = $OperatingSystem.Caption;
            "OSVersion"          = $OperatingSystem.version;
            "OU"                 = $OU;
            "Model"              = $ComputerSystem.Model;
            "MemoryGB"           = $ComputerSystem.TotalPhysicalMemory/1GB -as [int];
            "NumberOfProcessors" = $ComputerSystem.NumberOfProcessors;
            "NumberOfSockets"    = $Sockets;
            "NumberOfCores"      = $Cores;
            "Last Reboot"        = $LastBoot;
            "Uptime"             = $Uptime
            "LoggedInUser"       = $LoggedUserSplit1
            "LoggedUserDetails"  = $ADName + " - " + $ADJobTitle
            "LocalAdmins"        = $LocalAdmins
        }

        $output = New-Object -TypeName PSObject -Property $Info
        $output
        Write-Host
        $CitrixRequest = Read-Host "The next portion will take some time - verifying Citrix version... Press any key to continue or q to quit . . ."
        if ($CitrixRequest -eq "q") {
            Clear-Host
            Get-ComputerInfo
        }

        # Query registry values for Virtual Driver
        #$Registry = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $ComputerName)

        #$RegistryKey = "VirtualDriver"
        #$RegistryLocation = "SOFTWARE\WOW6432Node\Citrix\ICA Client\Engine\Configuration\Advanced\Modules\ICA 3.0"

        #$RegistryValue = $Registry.OpenSubKey($RegistryLocation)
        #$CitrixKeys = $RegistryValue.GetValue($RegistryKey)
        #$CitrixKeys


        # Query Product class
        $CitrixVersions = Get-WmiObject -Class win32_Product @Splatting | WHERE Vendor -LIKE "Citrix*" | Select Name,Version | Format-Table -ErrorAction Stop -ErrorVariable ProcessError
        $CitrixVersions

    }
    
    # Cleanup variables
    Remove-Variable -Name output, Info, ProcessError, Sockets, Cores, OperatingSystem, ComputerSystem, Processors, ComputerName, Computer, Credential, NetworkAdapter, ComputerType, ADName, ADJobTitle, LoggedUserName, OU, Uptime, LastBoot, Creds, IP, Days, Hours, Minutes, LoggedUserSplit1, LoggedUserSplit, DHCP, Groups, LocalAdmins, Proc, CitrixVersions, Everything_is_OK -ErrorAction SilentlyContinue

    Read-Host "Press any key to continue..."
    Clear-Host
    Get-ComputerInfo

}

Get-ComputerInfo $args[0]
