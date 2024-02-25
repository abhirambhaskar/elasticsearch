#!/bin/bash

# Ask for elastic password
read -p "Enter elastic password: " ELASTIC_PASSWORD

# Update Ubuntu
 apt update
 apt upgrade -y

# Install docker, docker-compose and Nginx
 apt install docker.io -y
 curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
 chmod +x /usr/local/bin/docker-compose
 apt install nginx -y

# Ask for domain names
read -p "Enter your domain name for kibana: " KIBANA_DOMAIN
read -p "Enter your domain name for elasticsearch: " ES_DOMAIN  # Added line

# Get public IP
PUBLIC_IP=$(curl -s ifconfig.co)

# Create Nginx config for Kibana
cat <<EOF > /etc/nginx/sites-available/$KIBANA_DOMAIN
server {
  listen 80;
  server_name $KIBANA_DOMAIN;

  location / {
    proxy_pass http://$PUBLIC_IP:5601;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
  }
}
EOF

# Create Nginx config for Elasticsearch  # Added block
cat <<EOF > /etc/nginx/sites-available/$ES_DOMAIN
server {
  listen 80;
  server_name $ES_DOMAIN;

  location / {
    proxy_pass http://$PUBLIC_IP:9200;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
  }
}
EOF  # End of added block

# Symlink to sites-enabled
 ln -s /etc/nginx/sites-available/$KIBANA_DOMAIN /etc/nginx/sites-enabled/
 ln -s /etc/nginx/sites-available/$ES_DOMAIN /etc/nginx/sites-enabled/  # Added line

# Test config
 nginx -t

# Reload Nginx
 systemctl reload nginx

# Create docker-compose.yml
cat <<EOF > docker-compose.yml
version: '3'
services:

  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:7.6.2
    volumes:
      - esdata:/usr/share/elasticsearch/data
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=true
      - xpack.security.authc.api_key.enabled=true
      - ELASTIC_PASSWORD=$ELASTIC_PASSWORD
    ports:
      - 9200:9200

  kibana:
    image: docker.elastic.co/kibana/kibana:7.6.2
    volumes:
      - kibanadata:/usr/share/kibana
    environment:
      - ELASTICSEARCH_USERNAME=elastic
      - ELASTICSEARCH_PASSWORD=$ELASTIC_PASSWORD
    ports:
      - 5601:5601
    depends_on:
      - elasticsearch

volumes:
  esdata:
    driver: local
  kibanadata:
    driver: local
EOF

# Start containers
docker-compose up -d

echo "Finished all working"
