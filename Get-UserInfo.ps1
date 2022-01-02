function Get-UserInfo {

    PARAM (
        [Parameter (Mandatory=$false)]
        $uname
    )

    Write-Host
    Write-Host "=====================================================" -ForegroundColor White
    Write-Host "          -- | User Info Retrieval Script | -- " -ForegroundColor Yellow
    Write-Host "=====================================================" -ForegroundColor White
    Write-Host

    $UserName = $uname

    if ([string]::IsNullOrWhitespace($uname)) {
        $UserName = Read-Host "Username"
    }

    if ([string]::IsNullOrWhitespace($UserName)) {
        $UserName = $env:username
    }

    Write-Host " - Checking AD for [" -NoNewLine
    Write-Host "$UserName" -ForegroundColor Magenta -NoNewLine
    Write-Host "]: " -NoNewline
    $user = $(try {Get-ADUser $UserName | select enabled} catch {$null})
    if ($user.Enabled -eq $true) {
        Write-Host "enabled" -ForegroundColor Green
    } elseif ($user.Enabled -eq $false) {
        Write-Host "disabled" -ForegroundColor Yellow
    } elseif ($user -eq $null) {
        Write-Host "does not exist" -ForegroundColor Red
        $UserName = $NULL
        Read-Host "Press any key to continue..."
        Clear-Host
        Get-UserInfo
    }

    Write-Host

    TRY {

        $Everything_is_OK = $true

        $userInfo = Get-ADUser $UserName -Properties *

        if ($userInfo.LockedOut) {
            $LockedSince = [DateTime]::FromFileTime($userInfo.lockoutTime)
            Write-Host "[WARNING] " -ForegroundColor Red
            Write-Host "[WARNING] " -ForegroundColor Red -NoNewLine
            Write-Host "User is currently locked out since: " -NoNewLine
            Write-Host $LockedSince
            Write-Host "[WARNING] " -ForegroundColor Red
        }

        if ($userInfo.AccountExpirationDate -ne $null) {
            $Today = (Get-Date)
            if (-Not($userInfo.AccountExpirationDate -lt $Today)) {
                Write-Host "[INFO]: " -ForegroundColor Yellow
                Write-Host "[INFO]: " -ForegroundColor Yellow -NoNewLine
                Write-Host "User is set to expire: " -NoNewLine
                Write-Host $userInfo.AccountExpirationDate
                Write-Host "[INFO]: " -ForegroundColor Yellow
            } else {
                Write-Host "[WARNING] " -ForegroundColor Red
                Write-Host "[WARNING] " -ForegroundColor Red -NoNewLine
                Write-Host "User has expired and will not be able to login as of: " -NoNewLine
                Write-Host $userInfo.AccountExpirationDate
                Write-Host "[WARNING] " -ForegroundColor Red
            }
        }

        $FirstName = $userInfo.GivenName
        $LastName = $userInfo.Surname
        $Email = $userInfo.EmailAddress
        $Title = $userInfo.Description
        $Department = $userInfo.Department
        $IsSupervisor = if ($userInfo.directReports -ne $null -or (($Title | select-string "supervisor") -or ($Title | select-string "manager") -or ($Title | select-string "director"))) { $True } else { $False }
        $ManagerSearch = if ($userInfo.Manager -ne $null) { Get-ADUser -Filter * -SearchBase $userInfo.Manager | select GivenName, Surname } else { $null }
        $Manager = if ($ManagerSearch -ne $null) { "$($ManagerSearch.GivenName) $($ManagerSearch.Surname)" } else { 'None' }
        $OfficePhone = if ($userInfo.OfficePhone -ne $null) { $userInfo.OfficePhone } else { 'None' }
        $LastLogon = [DateTime]::FromFileTime($userInfo.LastLogon)
        $ExchangeType = $userInfo.msExchRecipientTypeDetails
        $ExchangeCheck = if ($ExchangeType -eq 2147483648) { "O365" } elseif ($ExchangeType -eq 1) { "On-Prem" } else { 'Unknown' }
        $SIP = if ($userInfo.'msRTCSIP-PrimaryUserAddress' -ne $null) { $userInfo.'msRTCSIP-PrimaryUserAddress' } else { 'None' }
        $PasswordLastBadAttempt = $userInfo.LastBadPasswordAttempt
        $PasswordLastSet = $userInfo.PasswordLastSet
        $ADGroupImprivata = if ($userInfo.MemberOf | select-string "imprivata") { 'Yes' } else { 'No' }
        $ADGroupNetscaler = if ($userInfo.MemberOf | select-string "netscaler app") { 'Yes' } else { 'No' }
        $ADGroupVPN = if ($userInfo.MemberOf | select-string "vpn access") { 'Yes' } else { 'No' }


    }
    CATCH {
        $Everything_is_OK = $false
        Write-Warning -Message "Error on $UserName"
        $UserName | Out-File -FilePath $ErrorLog -Append -ErrorAction Continue
        $ProcessError | Out-File -FilePath $ErrorLog -Append -ErrorAction Continue
        Write-Warning -Message "Logged in $ErrorLog"
    }


    IF ($Everything_is_OK) {
        # Build output
        $esc = [char]27
        $green = 32
        $red = 31
        $yellow = 33
        $greenBright = 92
        $redBright = 91
        $yellowBright = 93
        $Info = [ordered]@{
            "Name"                      = "$($FirstName) $($LastName)";
            "Email"                     = $Email;
            "Title"                     = $Title;
            "Department"                = $Department;
            "Is Supervisor"             = if ($IsSupervisor) { "$esc[${greenBright}m$($IsSupervisor)$esc[0m" } else { "$esc[${red}m$($IsSupervisor)$esc[0m" };
            "Manager"                   = $Manager;
            "Office Phone"              = $OfficePhone;
            "Last Logon"                = $LastLogon;
            "Exchange Type"             = $ExchangeCheck;
            "SIP Address"               = $SIP;
            "Last Bad Password Attempt" = $PasswordLastBadAttempt;
            "Password Last Set Date"    = $PasswordLastSet;
            "AD Groups"                 = "----------------------------";
            "ImpSync"                   = if ($ADGroupImprivata -eq 'yes') { "$esc[${green}m$($ADGroupImprivata)$esc[0m" } else { "$esc[${redBright}m$($ADGroupImprivata)$esc[0m" };
            "Netscaler"                 = if ($ADGroupNetscaler -eq 'yes') { "$esc[${green}m$($ADGroupNetscaler)$esc[0m" } else { "$esc[${redBright}m$($ADGroupNetscaler)$esc[0m" };
            "VPN"                       = if ($ADGroupVPN -eq 'yes') { "$esc[${green}m$($ADGroupVPN)$esc[0m" } else { "$esc[${redBright}m$($ADGroupVPN)$esc[0m" };
        }

        $output = New-Object -TypeName PSObject -Property $Info
        $output

        if (($userInfo.LockedOut) -and ($user.Enabled -eq $true)) {
            Write-Host
            Write-Host "User is locked out. Type 'u' to unlock their account, or hit 'Enter' to continue." -ForegroundColor Magenta
            $UnlockAccount = Read-Host
            if ($UnlockAccount -eq 'u') {
                Unlock-ADAccount -Identity $UserName -Confirm
            }
        }

        if (($ADGroupImprivata -ne 'yes') -and ($user.Enabled -eq $true)) {
            Write-Host
            $AddToImprivata = Read-Host "Do you want to add user to ImprivataSynchronization AD group? (e.g. y or n)"
            if ($AddToImprivata -eq 'y') {
                Add-ADGroupMember -Identity ImprivataSynchronization -Members $UserName -Confirm
            }
        }

        Write-Host



    }
    
    # Cleanup variables
    Remove-Variable -Name output, Info, UserName, userInfo, user, FirstName, LastName, Email, Title, Department, IsSupervisor, OfficePhone,
    LastLogon, ExchangeType, ExchangeCheck, SIP, PasswordLastBadAttempt, PasswordLastSet, AddToImprivata, ADGroupImprivata, ADGroupNetscaler,
    ADGroupVPN, esc, green, greenBright, red, redBright, yellow, yellowBright, Everything_is_OK -ErrorAction SilentlyContinue

    Read-Host "Press any key to continue..."
    Clear-Host
    Get-UserInfo

}

Get-UserInfo $args[0]
