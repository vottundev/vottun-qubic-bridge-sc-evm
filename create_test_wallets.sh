#!/bin/bash

# Script para crear múltiples wallets de prueba para testing
# Uso: ./create_test_wallets.sh [número_de_wallets]

NUM_WALLETS=${1:-6}
WALLET_DIR="test_wallets"

echo "=========================================="
echo "Creando $NUM_WALLETS wallets de prueba"
echo "=========================================="
echo ""

# Crear directorio si no existe
mkdir -p $WALLET_DIR

# Array para almacenar direcciones
declare -a addresses
declare -a private_keys

for i in $(seq 1 $NUM_WALLETS); do
    echo "Creando wallet $i/$NUM_WALLETS..."
    
    # Crear wallet con cast
    WALLET_INFO=$(cast wallet new --unsafe-password "test" 2>&1)
    
    # Extraer address y private key
    ADDRESS=$(echo "$WALLET_INFO" | grep -oP 'Address:\s+\K0x[a-fA-F0-9]{40}')
    PRIVATE_KEY=$(echo "$WALLET_INFO" | grep -oP 'Private key:\s+\K0x[a-fA-F0-9]{64}')
    
    if [ -z "$ADDRESS" ] || [ -z "$PRIVATE_KEY" ]; then
        echo "Error creando wallet $i. Intentando método alternativo..."
        # Método alternativo: usar cast wallet vanity
        continue
    fi
    
    addresses[$i]=$ADDRESS
    private_keys[$i]=$PRIVATE_KEY
    
    echo "  ✓ Wallet $i creado: $ADDRESS"
done

echo ""
echo "=========================================="
echo "Resumen de Wallets Creados"
echo "=========================================="
echo ""

# Guardar en archivo
OUTPUT_FILE="$WALLET_DIR/wallets_info.txt"
echo "# Wallets de Prueba - $(date)" > $OUTPUT_FILE
echo "# IMPORTANTE: Estas son wallets de prueba. NO uses en mainnet!" >> $OUTPUT_FILE
echo "" >> $OUTPUT_FILE

for i in $(seq 1 ${#addresses[@]}); do
    if [ ! -z "${addresses[$i]}" ]; then
        echo "Wallet $i:" >> $OUTPUT_FILE
        echo "  Address:    ${addresses[$i]}" >> $OUTPUT_FILE
        echo "  Private Key: ${private_keys[$i]}" >> $OUTPUT_FILE
        echo "" >> $OUTPUT_FILE
        
        echo "Wallet $i:"
        echo "  Address:    ${addresses[$i]}"
        echo "  Private Key: ${private_keys[$i]}"
        echo ""
    fi
done

echo "=========================================="
echo "Información guardada en: $OUTPUT_FILE"
echo ""
echo "⚠️  IMPORTANTE:"
echo "1. Obtén ETH del faucet para cada wallet:"
echo "   https://docs.base.org/docs/tools/network-faucets"
echo "2. Para Base Sepolia, necesitas ~0.001 ETH por wallet"
echo "3. Estas private keys son SOLO para testing. NUNCA uses en mainnet!"
echo "=========================================="

# Crear archivo .env de ejemplo
ENV_FILE="$WALLET_DIR/.env.example"
echo "# Ejemplo de variables de entorno para testing" > $ENV_FILE
echo "BASE_SEPOLIA_RPC_URL=https://sepolia.base.org" >> $ENV_FILE
echo "" >> $ENV_FILE

for i in $(seq 1 ${#addresses[@]}); do
    if [ ! -z "${addresses[$i]}" ]; then
        echo "WALLET${i}_ADDRESS=${addresses[$i]}" >> $ENV_FILE
        echo "WALLET${i}_PRIVATE_KEY=${private_keys[$i]}" >> $ENV_FILE
        echo "" >> $ENV_FILE
    fi
done

echo "Archivo .env de ejemplo creado en: $ENV_FILE"

