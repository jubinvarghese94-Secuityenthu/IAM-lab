Import-Module ActiveDirectory

$UsersCSVPath   = "C:\ADBulk\users.csv"
$DomainSuffix   = "Marvel.local"
$ParentOUPath   = "OU=Marvel-Employees,DC=Marvel,DC=local"

$UsersData = Import-Csv -Path $UsersCSVPath

foreach ($User in $UsersData) {
    $TargetOUPath   = "OU=$($User.Department),$ParentOUPath"
    $UPN            = "$($User.SamAccountName)@$DomainSuffix"
    $SecurePassword = ConvertTo-SecureString $User.Password -AsPlainText -Force
    $DisplayName    = "$($User.FirstName) $($User.LastName)"

    # Check if user already exists
    if (-not (Get-ADUser -Filter "SamAccountName -eq '$($User.SamAccountName)'" -ErrorAction SilentlyContinue)) {
        try {
            # 1. Create User
            New-ADUser -Name $DisplayName `
                       -GivenName $User.FirstName `
                       -Surname $User.LastName `
                       -DisplayName $DisplayName `
                       -SamAccountName $User.SamAccountName `
                       -UserPrincipalName $UPN `
                       -Title $User.Title `
                       -Department $User.Department `
                       -Path $TargetOUPath `
                       -AccountPassword $SecurePassword `
                       -Enabled $true `
                       -ChangePasswordAtLogon $true

            Write-Host "[+] Created user: $($User.SamAccountName) ($DisplayName)" -ForegroundColor Green

            # 2. Add to Security Group
            if ($User.Group) {
                Add-ADGroupMember -Identity $User.Group -Members $User.SamAccountName
                Write-Host "    └ Added to group: $($User.Group)" -ForegroundColor DarkGreen
            }
        }
        catch {
            Write-Error "[-] Failed to provision $($User.SamAccountName): $_"
        }
    } else {
        Write-Host "[*] User already exists: $($User.SamAccountName), skipping creation." -ForegroundColor Yellow
    }
}