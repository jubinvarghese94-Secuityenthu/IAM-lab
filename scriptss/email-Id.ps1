Import-Module ActiveDirectory

$TargetEmail = "xcode143@gmail.com"

# List of SamAccountNames extracted from your selection
$UserList = @(
    "bdrake",
    "pcoulson",
    "nfury",
    "bbarnes",
    "cbarton",
    "cdanvers",
    "bbanner",
    "fcastle"
)

foreach ($Username in $UserList) {
    try {
        $User = Get-ADUser -Filter "SamAccountName -eq '$Username'" -ErrorAction Stop

        if ($User) {
            # Updates the Active Directory 'Mail' (E-mail) attribute
            Set-ADUser -Identity $Username -EmailAddress $TargetEmail

            Write-Host "[+] Successfully updated email for: $Username -> $TargetEmail" -ForegroundColor Green
        }
    }
    catch {
        Write-Warning "[-] User not found or error updating: $Username ($($_.Exception.Message))"
    }
}