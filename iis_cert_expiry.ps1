Import-Module WebAdministration

$dados = @()

$sites = Get-ChildItem IIS:\Sites

foreach ($site in $sites) {
    foreach ($binding in $site.Bindings.Collection) {
        $protocol = $binding.protocol
        $bindingInfo = $binding.bindingInformation

        $parts = $bindingInfo.Split(':')
        $hostname = $parts[2]

        if (-not $hostname) {
            $hostname = "localhost"
        }

        $url = "$($protocol)://$($hostname)"
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
                    $diasRestantes = -3  # Erro ao acessar a loja
                }
            } else {
                $diasRestantes = -4  # Binding sem hash
            }

            $dados += @{
                "{#SITE}"      = $site.Name
                "{#URL}"       = $url
                "{#HOSTNAME}"  = $hostname
                "{#DAYSLEFT}"  = $diasRestantes
            }
        }
    }
}

$resultado = @{ data = $dados }
$resultado | ConvertTo-Json -Depth 5
