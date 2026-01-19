#!/bin/bash
# Script para verificar qué contrato está desplegado y comparar con el código local

echo "=========================================="
echo "Verificación de Deployment"
echo "=========================================="
echo ""

# Direcciones encontradas en el proyecto
echo "Direcciones encontradas:"
echo "1. Broadcast (run-latest.json): 0x1f82ad883400e211cb538607d7f557f13249f489"
echo "2. Documentación (MANUAL_VERIFICATION.md): 0xbC79b4a96186b0AFE09Ee83830e2Fb30E14d5Ddc"
echo ""

# Parámetros del deployment según broadcast
echo "Parámetros del último deployment (según broadcast):"
echo "- baseFee: 200"
echo "- adminThreshold: 2"
echo "- managerThreshold: 2"
echo ""

# Parámetros en el script actual
echo "Parámetros en script/Deploy.s.sol (actual):"
echo "- baseFee: 5"
echo "- adminThreshold: 2"
echo "- managerThreshold: 2"
echo ""

echo "=========================================="
echo "Recomendaciones:"
echo "=========================================="
echo "1. Verificar en BaseScan cuál contrato está activo:"
echo "   https://sepolia.basescan.org/address/0x1f82ad883400e211cb538607d7f557f13249f489"
echo "   https://sepolia.basescan.org/address/0xbC79b4a96186b0AFE09Ee83830e2Fb30E14d5Ddc"
echo ""
echo "2. Comparar el bytecode del contrato desplegado con el compilado localmente:"
echo "   forge build"
echo "   # Luego comparar el bytecode en out/QubicBridge.sol/QubicBridge.json"
echo ""
echo "3. Si el código local difiere, actualizar:"
echo "   - Actualizar script/Deploy.s.sol con los parámetros correctos"
echo "   - Actualizar MANUAL_VERIFICATION.md con la dirección correcta"
echo "   - Actualizar verify_bridge.sh con la dirección correcta"
echo ""


