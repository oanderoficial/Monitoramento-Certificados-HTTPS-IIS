
# 🧩 Passo a passo no servidor IIS (Windows Server)

## ✅ 1. Criar pasta e salvar o script

- Criar a pasta:
  ```
  C:\Zabbix\scripts\
  ```

- Salvar o script como:
  ```
  iis_cert_expiry.ps1
  ```

---

## ✅ 2. Editar o arquivo de configuração do agente Zabbix

**Arquivo:**
```
C:\Zabbix\conf\zabbix_agent2.conf
```

Verifique/adicione as linhas:
```ini
Hostname=NOME_DO_HOST_NO_ZABBIX
UnsafeUserParameters=1
Include=C:\Zabbix\conf\UserParameters.conf
```

---

## ✅ 3. Criar o arquivo UserParameters.conf

**Caminho:**
```
C:\Zabbix\conf\UserParameters.conf
```

**Conteúdo:**
```ini
UserParameter=iis.cert.discovery,powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Zabbix\scripts\iis_cert_expiry.ps1"
UserParameter=iis.cert.expiry[*],powershell -NoProfile -ExecutionPolicy Bypass -Command "& { $url = '$1'; $result = (powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\Zabbix\scripts\iis_cert_expiry.ps1' | ConvertFrom-Json).data | Where-Object { $_.'{#URL}' -eq $url }; if ($result) { $result.'{#DAYSLEFT}' } else { -1 } }"
```

---

## ✅ 4. Reiniciar o agente Zabbix

Execute como administrador no PowerShell:
```powershell
Restart-Service zabbix-agent2
```

---

## ✅ 5. Testar localmente (opcional)

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Zabbix\scripts\iis_cert_expiry.ps1"
```
