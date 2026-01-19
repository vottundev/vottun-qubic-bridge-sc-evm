#!/bin/bash
# Script para verificar el contrato QubicBridge en Base Sepolia
# Ejecutar después de que se resetee el rate limit de BaseScan API (esperar 1-2 horas)

echo "=========================================="
echo "Verificando QubicBridge en Base Sepolia"
echo "=========================================="
echo ""
echo "Dirección del contrato: 0xbC79b4a96186b0AFE09Ee83830e2Fb30E14d5Ddc"
echo "Network: Base Sepolia (84532)"
echo ""

# Cargar variables de entorno
source .env

# Verificar el contrato
# NOTE: BaseScan APIs are deprecated - use ETHERSCAN_API_KEY for Base networks
forge verify-contract 0xbC79b4a96186b0AFE09Ee83830e2Fb30E14d5Ddc \
  src/QubicBridge.sol:QubicBridge \
  --chain base-sepolia \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --constructor-args 0000000000000000000000005438615e84178c951c0eb84ec9af1045ea2a7c78000000000000000000000000000000000000000000000000000000000000000500000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000020000000000000000000000007002b4761b7b836b20f07e680b5b95c7551971020000000000000000000000000000000000000000000000000000000000000003000000000000000000000000464800222d2ab38f696f0f74fe6a9fa5a2693e12000000000000000000000000db29aedd947eba1560dd31cffecf63bbb817ab4a0000000000000000000000007002b4761b7b836b20f07e680b5b95c755197102 \
  --watch

echo ""
echo "=========================================="
echo "Verificación completada!"
echo "=========================================="
