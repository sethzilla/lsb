# Array of required ports and protocols
$rules = @(
    @{ Name = "FFXI-LSB-TCP-51220"; Port = 51220; Protocol = "TCP" },
    @{ Name = "FFXI-LSB-TCP-54001"; Port = 54001; Protocol = "TCP" },
    @{ Name = "FFXI-LSB-TCP-54002"; Port = 54002; Protocol = "TCP" },
    @{ Name = "FFXI-LSB-TCP-54230"; Port = 54230; Protocol = "TCP" },
    @{ Name = "FFXI-LSB-TCP-54231"; Port = 54231; Protocol = "TCP" },
    @{ Name = "FFXI-LSB-TCP-54232"; Port = 54232; Protocol = "TCP" },
    @{ Name = "FFXI-LSB-UDP-54230"; Port = 54230; Protocol = "UDP" }
)

foreach ($rule in $rules) {
    $existingRule = Get-NetFirewallRule -DisplayName $rule.Name -ErrorAction SilentlyContinue
    
    if (-not $existingRule) {
        Write-Host "Creating firewall rule: $($rule.Name) for port $($rule.Port) $($rule.Protocol)..."
        New-NetFirewallRule -DisplayName $rule.Name `
            -Direction Inbound `
            -Action Allow `
            -Protocol $rule.Protocol `
            -LocalPort $rule.Port `
            -Program Any `
            -Profile Any | Out-Null
        Write-Host "Created successfully!"
    } else {
        Write-Host "Rule already exists: $($rule.Name)"
    }
}

Write-Host "`nAll required firewall rules are in place!"
Write-Host "You can verify these rules in Windows Defender Firewall with Advanced Security"