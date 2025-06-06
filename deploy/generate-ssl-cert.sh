#!/bin/bash
# Generate self-signed SSL certificate for local nginx
# For production, you'll use Cloudflare's SSL, but nginx needs a cert for Full mode

set -e

SSL_DIR="/home/jacobgood/theprogram5/deploy/nginx/ssl"
DOMAIN="dev.goodvaluation.com"

echo "Creating SSL directory..."
mkdir -p "$SSL_DIR"

echo "Generating self-signed certificate for $DOMAIN..."
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "$SSL_DIR/key.pem" \
    -out "$SSL_DIR/cert.pem" \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=$DOMAIN"

echo "Setting permissions..."
chmod 600 "$SSL_DIR/key.pem"
chmod 644 "$SSL_DIR/cert.pem"

echo "SSL certificate generated successfully!"
echo "Certificate: $SSL_DIR/cert.pem"
echo "Private key: $SSL_DIR/key.pem"
echo ""
echo "Note: This is a self-signed certificate for use with Cloudflare Full mode."
echo "Cloudflare will handle the real SSL certificate for your visitors."