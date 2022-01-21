function Find-User {
    
    PARAM (
        [Parameter (Mandatory=$false)]
        $search,

        $ErrorLog = "c:\Users\$env:USERNAME\Desktop\PSUserSearchErrors.log"
    )

    Write-Host
    Write-Host "=====================================================" -ForegroundColor White
    Write-Host "             -- | User Search Script | -- " -ForegroundColor Yellow
    Write-Host "=====================================================" -ForegroundColor White
    Write-Host

    $Search = $search

    if ([string]::IsNullOrWhitespace($search)) {
        $Search = $(Write-Host "Searching for: " -ForegroundColor Cyan -NoNewLine; Read-Host)
    }

    if ([string]::IsNullOrWhitespace($Search)) {
        $Search = $env:username
    }

    Write-Host " - Checking AD for [" -NoNewLine
    Write-Host "$Search" -ForegroundColor Magenta -NoNewLine
    Write-Host "]: " -NoNewline
    $user = $(try {Get-ADUser -LDAPFilter "(anr=$Search)"} catch {$null})

    $uCount = $(try {$user.Count} catch {$null})

    if ($uCount -gt 0 -Or $user.Enabled -eq $true) {
        Write-Host "Results found" -ForegroundColor Green -NoNewLine
        if ($user.Enabled -eq $true -And $uCount -eq $null) {
            Write-Host " [1]" -ForegroundColor Green
        } else {
            Write-Host " [$uCount]" -ForegroundColor Green
        }
    } elseif ($user.Count -eq 0) {
        Write-Host "No results found" -ForegroundColor Yellow
        $Search = $NULL
        Read-Host "Press ENTER to retry..."
        Clear-Host
        Find-User
    } elseif ($user -eq $null) {
        Write-Host "Search parameter failed" -ForegroundColor Red
        $Search = $NULL
        Read-Host "Press ENTER to retry..."
        Clear-Host
        Find-User
    }

    Write-Host

    TRY {

        $Everything_is_OK = $true

        if ($uCount -eq $null) {
            .\Get-UserInfo.ps1 $user.SAMAccountName
            Clear-Host
            Find-User
        } else {
            $userList = Get-ADUser -LDAPFilter "(anr=$Search)" -Properties Description | select Name, Description, Enabled, SAMAccountName | Sort-Object Name
            $Result = $userList | Out-GridView -Title "List of users based off of parameters [$Search]" -PassThru | Select-Object -ExpandProperty SAMAccountName

            if ($Result -ne $null) {
                .\Get-UserInfo.ps1 $Result
                Clear-Host
                Find-User
            } else {
                Clear-Host
                Find-User
            }

            Read-Host "Press ENTER to clear history..."

            Clear-Host
            Find-User
        }

    }
    CATCH {
        $Everything_is_OK = $false
        Write-Warning -Message "Error on $Search"
        $Search | Out-File -FilePath $ErrorLog -Append -ErrorAction Continue
        $ProcessError | Out-File -FilePath $ErrorLog -Append -ErrorAction Continue
        Write-Warning -Message "Logged in $ErrorLog"
    }


}

Find-User $args[0]
