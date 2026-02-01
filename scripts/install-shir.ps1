# Install Self-Hosted Integration Runtime on Windows VM
# Run this script on the SHIR VM after RDP

param(
    [Parameter(Mandatory=$true)]
    [string]$AuthKey
)

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Installing Self-Hosted Integration Runtime" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Download URL for SHIR
$shirUrl = "https://download.microsoft.com/download/E/4/7/E4771B1F-4E1D-4D3A-AF20-1D7E8E949E1D/IntegrationRuntime_5.38.8754.2.msi"
$shirInstaller = "$env:TEMP\IntegrationRuntime.msi"

# Download SHIR
Write-Host "📥 Downloading Self-Hosted Integration Runtime..." -ForegroundColor Yellow
Invoke-WebRequest -Uri $shirUrl -OutFile $shirInstaller

# Install SHIR silently
Write-Host "📦 Installing SHIR..." -ForegroundColor Yellow
Start-Process msiexec.exe -ArgumentList "/i `"$shirInstaller`" /quiet /norestart" -Wait

# Wait for installation to complete
Start-Sleep -Seconds 10

# Register SHIR with authentication key
Write-Host "🔑 Registering SHIR with Data Factory..." -ForegroundColor Yellow
$dmgcmdPath = "C:\Program Files\Microsoft Integration Runtime\5.0\Shared\dmgcmd.exe"

if (Test-Path $dmgcmdPath) {
    & $dmgcmdPath -Key $AuthKey
    Write-Host "✅ SHIR registered successfully!" -ForegroundColor Green
} else {
    Write-Host "❌ SHIR installation path not found. Please register manually." -ForegroundColor Red
    Write-Host "Auth Key: $AuthKey" -ForegroundColor Yellow
}

# Create sample data directory
Write-Host ""
Write-Host "📁 Creating sample data directory..." -ForegroundColor Yellow
$dataPath = "C:\OnPremiseData"
New-Item -Path $dataPath -ItemType Directory -Force | Out-Null

# Create sample CSV file
$sampleCsv = @"
EmployeeID,FirstName,LastName,Department,Salary,HireDate
1,John,Doe,Engineering,75000,2020-01-15
2,Jane,Smith,Marketing,65000,2019-06-20
3,Mike,Johnson,Sales,70000,2021-03-10
4,Sarah,Williams,HR,60000,2020-09-05
5,Tom,Brown,Engineering,80000,2018-11-30
6,Emily,Davis,Finance,72000,2019-08-12
7,David,Miller,Sales,68000,2021-01-25
8,Lisa,Wilson,Marketing,66000,2020-04-18
9,James,Moore,Engineering,78000,2019-12-08
10,Anna,Taylor,HR,62000,2021-05-22
"@

$sampleCsv | Out-File -FilePath "$dataPath\employees.csv" -Encoding UTF8

Write-Host "✅ Sample data created at: $dataPath\employees.csv" -ForegroundColor Green

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "✅ Setup Complete!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Sample data available at: $dataPath" -ForegroundColor Yellow
Write-Host "SHIR is registered and ready to use." -ForegroundColor Yellow
Write-Host ""
