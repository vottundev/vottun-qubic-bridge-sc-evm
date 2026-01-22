# Información del deployment – Qubic Bridge

---

## Último deployment (Base Sepolia)

| | Dirección | Tx |
|---|-----------|-----|
| **Token (WQUBIC)** | `0x6E4469ad1292EA46c1944DF30Fae358F8dba1C3a` | [0x9828ff...c2d1](https://sepolia.basescan.org/tx/0x9828ff3cda77129bceee03489229912653bc6c5c96865b31092667375a89c2d1) |
| **Bridge** | `0x4B2B1f138e9cA67bA8BE30B39895b5CC3dA8EF78` | [0x59b727...928](https://sepolia.basescan.org/tx/0x59b727df9a6c2461fe4b939f31591993fc3c68dcf36e96996fe983e9ce0a9928) |
| **addOperator** | — | [0xc39aef...b9bd](https://sepolia.basescan.org/tx/0xc39aef9facdabadb042102261fdb79c28b1892a804fd51fda430c58d98acb9bd) |

- **Red:** Base Sepolia (84532)  
- **Explorer:** https://sepolia.basescan.org/  
- **Datos completos (JSON):** `broadcast/Deploy.s.sol/84532/run-latest.json`

---

## Variables de entorno (`.env`)

| Variable | Uso |
|----------|-----|
| `TECNICO_KEY` | Clave privada para `--private-key` en el deploy (Forge la usa para firmar las tx). |
| `BASESCAN_API_KEY` | Verificación de contratos en **Base Sepolia** (Basescan). Obtener en [basescan.org](https://basescan.org/myapikey). |
| `ETHERSCAN_API_KEY` | Verificación en **Ethereum/Sepolia** (Etherscan). No se usa para Base Sepolia. |
| `BASE_SEPOLIA_RPC_URL` | Solo si usas `--rpc-url base_sepolia` en lugar de la URL pública. |

**Por qué `$env:TECNICO_KEY` puede estar vacío:** Forge sí lee `.env` para cosas internas (p. ej. `${VAR}` en `foundry.toml` y `vm.env*` en tests), pero **no** pone esas variables en la sesión de PowerShell. Al escribir `--private-key $env:TECNICO_KEY`, quien resuelve la variable es PowerShell; si no has cargado `.env` en la sesión, `$env:TECNICO_KEY` queda vacío.

**Solución:** Usar el script `deploy.ps1` (carga `.env` y lanza el deploy) o cargar `.env` a mano antes de ejecutar `forge script`.

**Verificación en Base Sepolia:** `foundry.toml` usa `BASESCAN_API_KEY` para Base Sepolia. Si quieres `--verify` al desplegar, añade `BASESCAN_API_KEY` en `.env` (puedes crearla en [basescan.org/myapikey](https://basescan.org/myapikey)). `ETHERSCAN_API_KEY` es para Etherscan (p. ej. Sepolia en Ethereum), no para Basescan.

---

## Cómo ejecutar el deploy

### Opción 1: Script `deploy.ps1` (recomendado en Windows)

Carga `.env` y ejecuta el deploy. En la raíz del proyecto:

```powershell
.\deploy.ps1
```

Si PowerShell bloquea scripts: `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass` y luego `.\deploy.ps1`.

Asegúrate de tener en `.env`:
```
TECNICO_KEY=0xtu_clave_privada_sin_0x_si_la_incluyes_igual_vale
```

---

### Opción 2: Forge a mano (cargando `.env` en PowerShell)

Si no usas `deploy.ps1`, hay que cargar `.env` en la sesión antes. En la raíz del proyecto:

```powershell
# Cargar .env en la sesión
Get-Content .env | ForEach-Object {
  if ($_ -match '^\s*([^#][^=]*)=(.*)$') {
    $k = $matches[1].Trim(); $v = $matches[2].Trim().Trim('"').Trim("'")
    [Environment]::SetEnvironmentVariable($k, $v, 'Process')
  }
}
# Después, el deploy
forge script script/Deploy.s.sol:QubicDeployScript --rpc-url "https://sepolia.base.org" --broadcast --private-key $env:TECNICO_KEY
```

---

### Opción 3: Bash (Linux/Mac) con `source .env`

```bash
set -a; source .env; set +a
forge script script/Deploy.s.sol:QubicDeployScript \
  --rpc-url "https://sepolia.base.org" \
  --broadcast \
  --private-key $TECNICO_KEY
```

(O bien pasa la clave en `--private-key` directamente; **no subas el `.env` a Git**.)

Requisitos:

- Red: Base Sepolia (chainId 84532). RPC público: `https://sepolia.base.org`
- La wallet de `TECNICO_KEY` debe tener ETH en Base Sepolia para gas.
- Si usas `--rpc-url base_sepolia`, define `BASE_SEPOLIA_RPC_URL` en `.env`.

---

## Parámetros del script `Deploy.s.sol`

| Parámetro | Valor | Descripción |
|-----------|--------|-------------|
| `baseFee` | 5 | 0.05% (5/10000 en 2 decimales) |
| `initialAdmins[0]` | `0x464800222D2AB38F696f0f74fe6A9fA5A2693E12` | Admin 1 |
| `initialAdmins[1]` | `0x0e60B83F83c5d2684acE779dea8A957e91D02475` | Admin 2 |
| `initialAdmins[2]` | `0x090378a9c80c5E1Ced85e56B2128c1e514E75357` | Admin 3 |
| `adminThreshold` | 2 | 2 de 3 admins para aprobar propuestas de admin |
| `managerThreshold` | 2 | 2 de 3 managers para aprobar propuestas de manager |
| `feeRecipient` | `0x090378a9c80c5E1Ced85e56B2128c1e514E75357` | Receptor de fees (mismo que Admin 3) |
| `minTransferAmount` | 1000 | Mínimo 1000 QUs por transferencia |
| `maxTransferAmount` | 0 | Sin tope (0 = ilimitado) |

---

## Transacciones que ejecuta el script

1. **CREATE QubicToken** – Deployment del token WQUBIC.
2. **CREATE QubicBridge** – Deployment del bridge con: `token`, `baseFee`, `initialAdmins`, `adminThreshold`, `managerThreshold`, `feeRecipient`, `minTransferAmount`, `maxTransferAmount`.
3. **CALL token.addOperator(bridge)** – Registra el bridge como operador del token (mint/burn).

---

## Dónde se guarda la información

Tras un `--broadcast` correcto, Foundry escribe:

- `broadcast/Deploy.s.sol/84532/run-latest.json` – Transacciones y direcciones.
- `broadcast/Deploy.s.sol/84532/run-<timestamp>.json` – Copia con timestamp.

En `run-latest.json`:

- `transactions[0]`: CREATE `QubicToken` → `contractAddress` = dirección del token.
- `transactions[1]`: CREATE `QubicBridge` → `contractAddress` = dirección del bridge, `arguments` con los parámetros del constructor.
- `transactions[2]`: CALL `addOperator(bridge)` en el token.

Cada transacción incluye `hash` una vez minada.

---

## Resumen para rellenar después del deploy

Tras un deploy real, rellena con los datos de `run-latest.json`:

| Dato | Dónde |
|------|--------|
| **Token (WQUBIC)** | `transactions[0].contractAddress` |
| **Bridge** | `transactions[1].contractAddress` |
| **Tx deploy Token** | `transactions[0].hash` |
| **Tx deploy Bridge** | `transactions[1].hash` |
| **Tx addOperator** | `transactions[2].hash` |
| **Chain** | 84532 (Base Sepolia) |
| **Explorer** | https://sepolia.basescan.org/ |

---

## Deploy solo Bridge: `DeployBridgeOnly.s.sol`

Si el token ya existe y solo quieres desplegar un nuevo bridge:

```powershell
forge script script/DeployBridgeOnly.s.sol:DeployBridgeOnlyScript --rpc-url "https://sepolia.base.org" --broadcast --private-key $env:TECNICO_KEY
```

Antes de ejecutarlo, cambia en el script la variable `existingToken` por la dirección de tu token.

Después del deploy, hay que **registrar el bridge como operador en el token**:

```
token.addOperator(<DIRECCION_DEL_NUEVO_BRIDGE>)
```

(solo el admin del token puede hacer esta llamada)

---

## Nota sobre el último intento de deploy

La última ejecución con `forge script ... --broadcast` **no completó el broadcast** porque Foundry exige un `--sender`/cuenta propia (no el default). El mensaje fue:

> You seem to be using Foundry's default sender. Be sure to set your own --sender.

Para un deploy real es necesario usar `--private-key` (o una cuenta configurada) con una wallet que tenga ETH en Base Sepolia. La simulación del script se ejecutó correctamente y mostró en consola las direcciones que se habrían desplegado con el sender por defecto; en un broadcast real las direcciones dependerán de tu wallet y nonce.
