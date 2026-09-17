Import-Module ActiveDirectory

$DomainDN       = "DC=Marvel,DC=local"
$ParentOUName   = "Marvel-Employees"
$ParentOUPath   = "OU=$ParentOUName,$DomainDN"
$GroupsCSVPath  = "C:\ADBulk\groups.csv"

# 1. Create Top-Level Organizational Unit
if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$ParentOUName'" -ErrorAction SilentlyContinue)) {
    New-ADOrganizationalUnit -Name $ParentOUName -Path $DomainDN -ProtectedFromAccidentalDeletion $false
    Write-Host "[+] Created Parent OU: $ParentOUName" -ForegroundColor Green
} else {
    Write-Host "[*] Parent OU already exists: $ParentOUName" -ForegroundColor Yellow
}

# 2. Import CSV and Create Child OUs & Security Groups
$GroupsData = Import-Csv -Path $GroupsCSVPath

foreach ($row in $GroupsData) {
    $TargetOUPath = "OU=$($row.OUName),$ParentOUPath"

    # Create Child OU
    if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$($row.OUName)'" -SearchBase $ParentOUPath -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name $row.OUName -Path $ParentOUPath -ProtectedFromAccidentalDeletion $false
        Write-Host "[+] Created OU: $($row.OUName)" -ForegroundColor Green
    }

    # Create Security Group inside its OU
    if (-not (Get-ADGroup -Filter "SamAccountName -eq '$($row.GroupName)'" -ErrorAction SilentlyContinue)) {
        New-ADGroup -Name $row.GroupName `
                    -SamAccountName $row.GroupName `
                    -GroupScope Global `
                    -GroupCategory Security `
                    -Path $TargetOUPath `
                    -Description $row.Description
        Write-Host "[+] Created Group: $($row.GroupName) in $($row.OUName)" -ForegroundColor Cyan
    } else {
        Write-Host "[*] Group already exists: $($row.GroupName)" -ForegroundColor Yellow
    }
}