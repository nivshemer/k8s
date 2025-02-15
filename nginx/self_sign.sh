#!/bin/bash
# Store the variables passed from the main script
VARDOMAIN=$1
# Replace the domain in files under $NOLUCK
find "$NOLUCK" -type f -exec sed -i "s/nolucksecurity\.nl/$VARDOMAIN/g" {} +

# Steps to Create a Certificate Without Prompts
cd "$NOLUCK/nginx"

# Generate private key
sudo openssl genpkey -algorithm RSA -out cert.key -pkeyopt rsa_keygen_bits:2048 >> $NOLUCK/log.log 2>&1

# Generate certificate signing request (CSR) without prompts
sudo openssl req -new -key cert.key -out cert.csr -config nolucksecurity.cnf -batch >> $NOLUCK/log.log 2>&1
sudo openssl x509 -req -in cert.csr -signkey cert.key -out cert.crt -days 3650 -extfile nolucksecurity.cnf -extensions req_ext >> $NOLUCK/log.log 2>&1

if [ -d "/tmp/cert" ]; then
    echo "Using client's certificate" >> $NOLUCK/log.log 2>&1
    mv -v /tmp/cert/cert.crt $NOLUCK/nginx/cert.crt
    mv -v /tmp/cert/cert.key $NOLUCK/nginx/cert.key
else
    echo "/tmp/cert does not exist." >> $NOLUCK/log.log 2>&1
    # Check if there is access to the outside and "/tmp/utilities" does not exist
    if ping -c 1 8.8.8.8 &> /dev/null && [ ! -d "/tmp/utilities" ]; then
        echo "Internet access is available. Using GoDaddy's certificate" >> $NOLUCK/log.log 2>&1
        mv -v $NOLUCK/nginx/cert.crt $NOLUCK/nginx/self_cert.crt
        mv -v $NOLUCK/nginx/cert.key $NOLUCK/nginx/self_cert.key
        mv -v $NOLUCK/nginx/_cert.crt $NOLUCK/nginx/cert.crt
        mv -v $NOLUCK/nginx/_cert.key $NOLUCK/nginx/cert.key
    fi
fi



