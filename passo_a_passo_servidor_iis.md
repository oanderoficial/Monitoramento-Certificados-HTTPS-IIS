
# Passo a passo no servidor IIS (Windows Server)

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


**Para a nova versão do script use:**

```ini
UserParameter=iis.cert.discovery,powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Zabbix\scripts\iis_cert_expiry.ps1"
UserParameter=iis.cert.expiry[*],powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Zabbix\scripts\iis_cert_expiry.ps1" "$1"
```
---

## ✅ 4. Testar localmente (opcional)

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Zabbix\scripts\iis_cert_expiry.ps1"
```

## ✅ 5. Vincule o template (Certificados IIS) no host 
<img width="578" alt="image" src="https://github.com/user-attachments/assets/80352349-2cf8-4243-b512-0687f394cc8b" />

## ✅ 6. Reiniciar o agente Zabbix no servidor


---
