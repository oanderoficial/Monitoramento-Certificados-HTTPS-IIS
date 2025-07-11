
# Guia de Implementação: Monitoramento de Certificados HTTPS no IIS via Zabbix (v5 e v7)

## Objetivo
Implementar um monitoramento automático de certificados HTTPS vinculados aos sites do IIS, utilizando script PowerShell, Zabbix Agent 2, discovery rule e triggers, compatível com Zabbix 5 e 7.

---

## Requisitos

- Host Windows com IIS  
- Zabbix Agent 2 instalado  
- Zabbix Server (v5 ou v7)  
- Permissão para criar templates e editar arquivos do agente  

---

## 1. Preparar o Script PowerShell

### Caminho do script:
`C:\Zabbix\scripts\iis_cert_expiry.ps1`

### Conteúdo do script:
```powershell
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
```

---

## 2. Configurar o Zabbix Agent 2

### Arquivo de configuração:
`C:\Zabbix\conf\zabbix_agent2.conf`

### Verifique se o campo `Hostname` está correto:
```ini
Hostname=EXATAMENTE_COMO_ESTA_NO_ZABBIX_FRONTEND
```

### Adicione:
```ini
UnsafeUserParameters=1
Include=C:\Zabbix\conf\UserParameters.conf
```

### Conteúdo de `UserParameters.conf`:

```ini
UserParameter=iis.cert.discovery,powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Zabbix\scripts\iis_cert_expiry.ps1"
UserParameter=iis.cert.expiry[*],powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Zabbix\scripts\iis_cert_expiry.ps1" "$1"
```

### Reiniciar o agente:
```powershell
Restart-Service zabbix-agent2
```

---

##  3. Criar o Template no Zabbix

### 3.1 Criar Template:
- Nome: `Template Certificados IIS`  
- Grupo: `Templates`  

### 3.2 Criar Application (Zabbix 5 apenas):
- Nome: `Certificados IIS`

### 3.3 Criar Discovery Rule:
- Nome: `Descoberta de sites HTTPS (IIS)`  
- Tipo: `Zabbix agent`  
- Key: `iis.cert.discovery`  
- Intervalo: `3600`  
- Keep lost resources: `30d`

### 3.4 Criar Item Prototype:
- Nome: `Dias até expirar certificado para {#URL}`  
- Key: `iis.cert.expiry[{#URL}]`  
- Tipo: `Zabbix agent`  
- Dado: `Numeric (unsigned)`  
- Unidade: `d`  
- Application: `Certificados IIS` (Zabbix 5)

### 3.5 Criar Trigger Prototype:
- Nome: `⚠️ Certificado do site {#URL} vence em {ITEM.LASTVALUE1} dias`  
- Expressão:
```zabbix
{Template Certificados IIS:iis.cert.expiry[{#URL}].last()}<=30 and {Template Certificados IIS:iis.cert.expiry[{#URL}].last()}>0
```
- Severidade: Warning

---

## 4. Associar o Template ao Host

- Vá em `Configuration → Hosts → [seu host]`
- Aba `Templates`
- Adicione o `Template Certificados IIS`

---

## 5. Testes e Validação

### No host Windows:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Zabbix\scripts\iis_cert_expiry.ps1"
```

### No Zabbix Server:
```bash
zabbix_get -s <IP_DO_HOST_WINDOWS> -k iis.cert.discovery
```

### No frontend:
- Monitoring → Latest data
- Monitoring → Discovery
- Configuration → Hosts → [seu host] → Items / Triggers

---

## Significado dos valores especiais

| Valor retornado | Significado                                                               |
|------------------|---------------------------------------------------------------------------|
| `> 0`            | Dias restantes até expiração (normal)                                     |
| `-2`             | Binding HTTPS existe, mas **sem certificado vinculado**                   |
| `-3`             | Erro ao acessar a loja de certificados                                    |
| `-4`             | Binding HTTPS sem hash de certificado                                     |
| `-1`             | URL não encontrada no JSON (fallback no item do UserParameter)            |

---

## Observações finais

- Valor `-2` pode ser ignorado ou gerar trigger informativa
- Trocas de certificado ou novos sites HTTPS são detectados automaticamente
- Você pode desativar triggers específicas por URL se for esperado

---
