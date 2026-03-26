#!/bin/bash
# Script pour trouver l'ID du template Proxmox

set -e

# Couleurs
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Recherche du template Proxmox ===${NC}"
echo ""

# Variables nécessaires
read -p "URL Proxmox (ex: https://192.168.5.3:8006): " PM_API_URL
read -p "Token API (ex: root@pam!devver): " PM_TOKEN_ID
read -sp "Secret Token API: " PM_TOKEN_SECRET
echo ""
read -p "Nœud Proxmox (ex: PROXMOX-PVE1): " PM_NODE
read -p "Nom du template à chercher (ex: debian13-cloudinit): " TEMPLATE_NAME

echo ""
echo -e "${BLUE}Recherche en cours...${NC}"

# Requête API Proxmox
RESPONSE=$(curl -s -k -H "Authorization: PveAPIToken=${PM_TOKEN_ID}=${PM_TOKEN_SECRET}" \
  "${PM_API_URL}/api2/json/nodes/${PM_NODE}/qemu" 2>/dev/null)

# Parse JSON pour trouver le template
TEMPLATE_ID=$(echo "$RESPONSE" | grep -o "\"vmid\":[0-9]*" | grep -B5 "$TEMPLATE_NAME" | grep '"vmid"' | tail -1 | cut -d: -f2)

if [ -z "$TEMPLATE_ID" ]; then
    echo -e "${RED}❌ Template '$TEMPLATE_NAME' introuvable sur le nœud $PM_NODE${NC}"
    echo ""
    echo "VMs disponibles:"
    echo "$RESPONSE" | grep -o '"name":"[^"]*"' | cut -d'"' -f4
    exit 1
fi

echo ""
echo -e "${GREEN}✅ Template trouvé!${NC}"
echo -e "Nom: ${BLUE}$TEMPLATE_NAME${NC}"
echo -e "ID:  ${BLUE}$TEMPLATE_ID${NC}"
echo ""
echo "Ajouter cette ligne dans terraform.tfvars:"
echo -e "${GREEN}vm_template_id = $TEMPLATE_ID${NC}"
