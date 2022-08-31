function Compare-Groups {
    
    PARAM (
        [Parameter (Mandatory=$false)] $firstUser,
        [Parameter (Mandatory=$false)] $secondUser,

        $ErrorLog = "c:\Users\$env:USERNAME\Desktop\PSUserGroupsComparisonErrors.log"
    )

    Write-Host
    Write-Host "=====================================================" -ForegroundColor White
    Write-Host "      -- | User Groups Comparison Script | -- " -ForegroundColor Yellow
    Write-Host "=====================================================" -ForegroundColor White
    Write-Host

    Write-Host "Enter the usernames of the users you are comparing."

    $Compare = $null

    if ([string]::IsNullOrWhitespace($firstUser)) {
        $firstUser = $(Write-Host "First User: " -ForegroundColor Cyan -NoNewLine; Read-Host)
    }

    if ([string]::IsNullOrWhitespace($secondUser)) {
        $secondUser = $(Write-Host "Second User: " -ForegroundColor Cyan -NoNewLine; Read-Host)
    }

    Write-Host " - Checking AD for first user [" -NoNewLine
    Write-Host "$firstUser" -ForegroundColor Magenta -NoNewLine
    Write-Host "]: " -NoNewline
    $fuser = $(try {Get-ADUser -LDAPFilter "(anr=$firstUser)"} catch {$null})
    $fuCount = $(try {$fuser.Count} catch {$null})    

    if ($fuser -ne $null) {
        Write-Host "First user found." -ForegroundColor Green
    } else {
        Write-Host "First user not found." -ForegroundColor Red
        Read-Host "Press ENTER to retry..."
        Clear-Host
        Compare-Groups
    }

    Write-Host " - Checking AD for second user [" -NoNewLine
    Write-Host "$secondUser" -ForegroundColor Magenta -NoNewLine
    Write-Host "]: " -NoNewline
    $suser = $(try {Get-ADUser -LDAPFilter "(anr=$secondUser)"} catch {$null})
    $suCount = $(try {$suser.Count} catch {$null})

    if ($suser -ne $null) {
        Write-Host "Second user found." -ForegroundColor Green -NoNewLine
    } else {
        Write-Host "Second user not found." -ForegroundColor Red -NoNewLine
        Read-Host "Press ENTER to retry..."
        Clear-Host
        Compare-Groups
    }

    if ($suser -eq $null -or $fuser -eq $null) {
        Write-Host "Search parameter failed" -ForegroundColor Red -NoNewLine
        Read-Host "Press ENTER to retry..."
        Clear-Host
        Find-User
    }

    Write-Host

    TRY {

        $Everything_is_OK = $true

        $Compare = Compare-Object -ReferenceObject (Get-AdPrincipalGroupMembership $firstUser | select name | sort-object -Property name) -DifferenceObject (Get-AdPrincipalGroupMembership $secondUser | select name | sort-object -Property name) -property name

        $Compare | Out-Host

        Write-Host

        Read-Host "Press ENTER to clear history..."

        Clear-Host
        Compare-Groups
    }
    CATCH {
        $Everything_is_OK = $false
        Write-Warning -Message "Error on comparing groups"
        $firstUser | Out-File -FilePath $ErrorLog -Append -ErrorAction Continue
        $secondUser | Out-File -FilePath $ErrorLog -Append -ErrorAction Continue
        $Compare | Out-File -FilePath $ErrorLog -Append -ErrorAction Continue
        $ProcessError | Out-File -FilePath $ErrorLog -Append -ErrorAction Continue
        Write-Warning -Message "Logged in $ErrorLog"
    }


}

Compare-Groups $args[0] $args[1]