param (
    [string]$url
)

Import-Module WebAdministration

$dados = @()
$sites = Get-ChildItem IIS:\Sites

foreach ($site in $sites) {
    foreach ($binding in $site.Bindings.Collection) {
        $protocol = $binding.protocol
        $bindingInfo = $binding.bindingInformation
        $parts = $bindingInfo.Split(':')
        $hostname = $parts[2]

        if (-not $hostname) { $hostname = "localhost" }
        $siteUrl = "$($protocol)://$($hostname)"
        $diasRestantes = "N/A"

        if ($protocol -eq "https") {
            $certHash = $binding.CertificateHash
            $storeName = $binding.CertificateStoreName

            if ($certHash) {
                try {
                    $store = New-Object System.Security.Cryptography.X509Certificates.X509Store $storeName, 'LocalMachine'
                    $store.Open('ReadOnly')
                    $hashString = -join ($certHash | ForEach-Object { '{0:X2}' -f $_ })
                    $cert = $store.Certificates | Where-Object { $_.GetCertHashString() -eq $hashString }

                    if ($cert) {
                        $diasRestantes = ($cert.NotAfter - (Get-Date)).Days
                    } else {
                        $diasRestantes = -2  # Certificado não encontrado
                    }

                    $store.Close()
                } catch {
                    $diasRestantes = -3  # Erro ao acessar loja
                }
            } else {
                $diasRestantes = -4  # Binding sem hash
            }

            $dados += @{
                "{#SITE}"     = $site.Name
                "{#URL}"      = $siteUrl
                "{#HOSTNAME}" = $hostname
                "{#DAYSLEFT}" = $diasRestantes
            }
        }
    }
}

if ($url) {
    # Modo consulta por URL
    try {
        $json = @{ data = $dados } | ConvertTo-Json -Depth 5
        $parsed = $json | ConvertFrom-Json
        $match = $parsed.data | Where-Object { $_.'{#URL}' -eq $url }
        if ($match) {
            $match.'{#DAYSLEFT}'
        } else {
            -1  # URL não encontrada
        }
    } catch {
        -2  # Erro ao interpretar JSON
    }
} else {
    # Modo discovery
    @{ data = $dados } | ConvertTo-Json -Depth 5 | Out-String
}
