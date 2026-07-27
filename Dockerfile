FROM node:18

LABEL org.opencontainers.image.source="https://github.com/buddhikapp/aiva"
LABEL snapflow:run="875f7268-8bcd-4fae-9672-1723e5d56aed"
LABEL snapflow:step="2"

ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        dialog \
        git \
        net-tools \
        nginx \
        postgresql \
        postgresql-contrib \
        python3-dev \
        python3-pip \
        python3-setuptools \
        software-properties-common \
        supervisor \
    && rm -rf /var/lib/apt/lists/*

# Replace the default Nginx configuration file
COPY config/nginx.conf /etc/nginx/

# Add a supervisor configuration file
COPY config/supervisord.conf /etc/supervisor/conf.d/

# Define mountable directories
VOLUME ["/var/log"]

# Define working directory
RUN mkdir -p /var/www/aiva

WORKDIR /var/www/aiva
COPY package.json ./
COPY . ./

# Configure PostgreSQL for local trust auth and start it for setup
RUN pg_lsclusters | awk 'NR>1{print $1, $2}' | while read ver name; do \
        sed -i 's/peer/trust/g; s/scram-sha-256/trust/g; s/md5/trust/g' /etc/postgresql/$ver/$name/pg_hba.conf; \
    done \
    && pg_lsclusters | awk 'NR>1{print $1, $2}' | while read ver name; do \
        pg_ctlcluster $ver $name start; \
    done \
    && npm install \
    && npm run setup \
    && pg_lsclusters | awk 'NR>1{print $1, $2}' | while read ver name; do \
        pg_ctlcluster $ver $name stop; \
    done

# Expose ports for prod/dev, see config/
EXPOSE 4039 4040 4038 4041 7472 7474 7475 7476 6463 6464 6465 6466

# Default command
CMD ["supervisord", "-n"]
