#!/bin/bash

set -e

if [ -z "$1" ]; then
    echo "Usage: ./init-letsencrypt.sh <domain> [email]"
    echo "Example: ./init-letsencrypt.sh form4x.com admin@form4x.com"
    exit 1
fi

DOMAIN=$1
EMAIL=${2:-""}
DATA_PATH="./certbot"
RSA_KEY_SIZE=4096

if [ -d "$DATA_PATH/conf/live/$DOMAIN" ]; then
    read -p "Sertifikat untuk $DOMAIN sudah ada. Timpa? (y/N) " decision
    if [ "$decision" != "Y" ] && [ "$decision" != "y" ]; then
        exit 0
    fi
fi

echo "### Membuat direktori certbot..."
mkdir -p "$DATA_PATH/conf/live/$DOMAIN"
mkdir -p "$DATA_PATH/www"

echo "### Mendownload parameter SSL (dhparam, options-ssl)..."
if [ ! -e "$DATA_PATH/conf/options-ssl-nginx.conf" ]; then
    curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf > "$DATA_PATH/conf/options-ssl-nginx.conf"
fi
if [ ! -e "$DATA_PATH/conf/ssl-dhparams.pem" ]; then
    curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem > "$DATA_PATH/conf/ssl-dhparams.pem"
fi

echo "### Membuat sertifikat dummy untuk $DOMAIN ..."
openssl req -x509 -nodes -newkey rsa:$RSA_KEY_SIZE -days 1 \
    -keyout "$DATA_PATH/conf/live/$DOMAIN/privkey.pem" \
    -out "$DATA_PATH/conf/live/$DOMAIN/fullchain.pem" \
    -subj "/CN=localhost"
cp "$DATA_PATH/conf/live/$DOMAIN/fullchain.pem" "$DATA_PATH/conf/live/$DOMAIN/chain.pem"

echo "### Menjalankan nginx dengan sertifikat dummy..."
DOMAIN=$DOMAIN docker compose up -d nginx

echo "### Menghapus sertifikat dummy..."
rm -rf "$DATA_PATH/conf/live/$DOMAIN"

echo "### Meminta sertifikat Let's Encrypt untuk $DOMAIN ..."

if [ -z "$EMAIL" ]; then
    EMAIL_ARG="--register-unsafely-without-email"
else
    EMAIL_ARG="--email $EMAIL --no-eff-email"
fi

docker compose run --rm certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    $EMAIL_ARG \
    -d "$DOMAIN" \
    --agree-tos \
    --force-renewal

echo "### Merestart nginx dengan sertifikat asli..."
docker compose restart nginx

echo ""
echo "=========================================="
echo "  SSL berhasil diaktifkan untuk $DOMAIN"
echo "  Sertifikat akan auto-renew via certbot"
echo "=========================================="
