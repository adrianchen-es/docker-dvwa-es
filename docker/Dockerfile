ARG VERSION 8.1

FROM php:${VERSION}-apache as builder

# Install requirements
RUN set -eux \
        && apt-get update \
        && apt-get install -y --no-install-recommends --no-install-suggests \
                git \
                ca-certificates \
        && update-ca-certificates

# Get DVWA
RUN set -eux \
        && git clone https://github.com/digininja/DVWA /DVWA \
        && rm -rf /DVWA/.git \
        && rm -rf /DVWA/.github \
        && rm -rf /DVWA/.gitignore \
        && rm -rf /DVWA/php.ini

# Disable SQLITE
RUN set -eux \
        && sed -i'' "s/if (\$_DVWA\['SQLI_DB'\]/if ('no'/g" /DVWA/dvwa/includes/dvwaPage.inc.php \
        && sed -i'' 's/[[:space:]]SQLITE)/"SQLITE")/g' /DVWA/dvwa/includes/dvwaPage.inc.php

# Get Adminer
RUN set -eux \
        && URL="$( \
                curl -sS --fail -k https://www.adminer.org/ \
                | grep -Eo 'https://github.com/vrana/adminer/releases/download/v[.0-9]+/adminer-[.0-9]+-mysql-en.php' \
        )" \
        && curl -sS --fail -k -L "${URL}" > /adminer.php

FROM php:${VERSION}-apache


ARG ARG_AGENT_VERSION=8.9.1
ARG ARG_PHP_AGENT_VER=1.9.1

## Accept either rum or opentracing
ARG ARG_RUM_TYPE=rum
ARG ARG_RUM_VER=5.14.0

# Set Environment Vars based on Build ARGs
ENV AGENT_VERSION $ARG_AGENT_VERSION
ENV PHP_AGENT_VER $ARG_PHP_AGENT_VER
ENV RUM_TYPE $ARG_RUM_TYPE
ENV RUM_VER $ARG_RUM_VER


# Satisfy PHP requirements
RUN set -eux \
        && apt-get update \
        && apt-get install -y --no-install-recommends --no-install-suggests \
                libpng-dev \
                ca-certificates \
        && update-ca-certificates \
        && docker-php-ext-install gd \
        && docker-php-ext-install mysqli \
        && docker-php-ext-install pdo_mysql \
        && apt-get clean \
        && rm -rf /var/lib/apt/lists/*

# Satisfy Application requirements
RUN set -eux \
        && apt-get update \
        && apt-get install -y --no-install-recommends --no-install-suggests \
                iputils-ping \
                netcat-traditional \
                python3 \
                strace \
                sudo \
                telnet \
        && apt-get clean \
        && rm -rf /var/lib/apt/lists/*

# Copy source
COPY --from=builder /DVWA/ /var/www/html/
COPY --from=builder /adminer.php /var/www/html/adminer.php
COPY ./config.inc.php /var/www/html/config/config.inc.php
COPY ./entrypoint.sh/ /entrypoint.sh


# Configure CTF challenges
COPY ./ctf/setup /tmp/setup
RUN set -eu \
        && cmd="$(cat /tmp/setup)" \
        && for i in $(seq 20); do cmd="$(echo "${cmd}" | base64 -d)"; done \
        && echo "${cmd}" | sh 2>/dev/null \
        && rm /tmp/setup


# Pull the JS agent
RUN set -e ; \
  mkdir -p /var/www/html/js; \
  curl --retry 8 -S -L -O "https://unpkg.com/@elastic/apm-rum@${RUM_VER}/dist/bundles/elastic-apm-${RUM_TYPE}.umd.min.js" ; \
  mv "elastic-apm-${RUM_TYPE}.umd.min.js" /var/www/html/js/elastic-apm.umd.min.js

# Pull the agent
RUN set -e ; \
  case "$(arch)" in \
    x86_64) \
        AGENT="elastic-agent-${AGENT_VERSION}-linux-x86_64"; \
        ;; \
    aarch64) \
        AGENT="elastic-agent-${AGENT_VERSION}-linux-arm64"; \
        ;; \
    *) \
        echo >&2 ; echo >&2 "Unsupported architecture \$(arch)" ; echo >&2 ; exit 1 ; \
        ;; \
  esac ; \
  curl --retry 8 -S -L -O "https://artifacts.elastic.co/downloads/beats/elastic-agent/${AGENT}.tar.gz" ; \
  mv "${AGENT}.tar.gz" /tmp ; \
  cd /tmp && tar xzf "${AGENT}.tar.gz"; \
  cd "${AGENT}" && ./elastic-agent install --non-interactive; \
  rm -rf "/tmp/${AGENT}"

ENV BEAT_SETUID_AS=root

ENV LIBBEAT_MONITORING_CGROUPS_HIERARCHY_OVERRIDE=/

ENV ELASTIC_CONTAINER "true"
ENV PATH=/opt/Elastic/Agent/:$PATH
ENV GODEBUG="madvdontneed=1"

# Add an init process, check the checksum to make sure it's a match
RUN set -e ; \
  TINI_BIN=""; \
  TINI_SHA256=""; \
  TINI_VERSION="v0.19.0"; \
  case "$(arch)" in \
    x86_64) \
        TINI_BIN="tini-amd64"; \
        TINI_SHA256="93dcc18adc78c65a028a84799ecf8ad40c936fdfc5f2a57b1acda5a8117fa82c"; \
        ;; \
    aarch64) \
        TINI_BIN="tini-arm64"; \
        TINI_SHA256="07952557df20bfd2a95f9bef198b445e006171969499a1d361bd9e6f8e5e0e81"; \
        ;; \
    *) \
        echo >&2 ; echo >&2 "Unsupported architecture \$(arch)" ; echo >&2 ; exit 1 ; \
        ;; \
  esac ; \
  curl --retry 8 -S -L -O "https://github.com/krallin/tini/releases/download/${TINI_VERSION}/${TINI_BIN}" ; \
  echo "${TINI_SHA256} ${TINI_BIN}" | sha256sum -c - ; \
  mv "${TINI_BIN}" /usr/bin/tini ; \
  chmod +x /usr/bin/tini

RUN set -eux \
        && chmod +x /entrypoint.sh

COPY ./elastic-agent.yml /opt/Elastic/Agent/elastic-agent.yml

COPY ./elasticagent-dockerentry.sh /usr/local/bin/docker-entrypoint
RUN chmod 755 /usr/local/bin/docker-entrypoint

#CMD ["/usr/bin/tini", "--", "/usr/local/bin/docker-entrypoint","/entrypoint.sh"]


## Elastic Endpoint Deployment
RUN apt-get update -y \
    && apt-get upgrade -y \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        ca-certificates \
    && apt-get clean

# Pull the agent
RUN set -e ; \
  case "$(arch)" in \
    x86_64) \
        ENDPOINT="endpoint-security-${AGENT_VERSION}-linux-x86_64"; \
        ;; \
    aarch64) \
        ENDPOINT="endpoint-security-${AGENT_VERSION}-linux-arm64"; \
        ;; \
    *) \
        echo >&2 ; echo >&2 "Unsupported architecture \$(arch)" ; echo >&2 ; exit 1 ; \
        ;; \
  esac ; \
  curl --retry 8 -S -L -O "https://artifacts.elastic.co/downloads/endpoint-dev/${ENDPOINT}.tar.gz" ; \
  mv "${ENDPOINT}.tar.gz" /tmp ; \
  mkdir -p /tmp/installer; \
    tar -xzf "/tmp/${ENDPOINT}.tar.gz" --strip-components 1 -C /tmp/installer \
    && /tmp/installer/endpoint-security install \
        --no-system-services \
        --resources /tmp/installer/endpoint-security-resources.zip \
    && rm -rf /tmp/installer \
    && rm -f "/tmp/${ENDPOINT}.tar.gz" \
    && rm -f /opt/Elastic/Endpoint/elastic-endpoint.yaml

# Install endpoint.
#RUN mkdir -p /tmp/installer \
#    && tar -xzf /tmp/endpoint-security.tar.gz --strip-components 1 -C /tmp/installer \
#    && /tmp/installer/endpoint-security install \
#        --no-system-services \
#        --resources /tmp/installer/endpoint-security-resources.zip \
#    && rm -rf /tmp/installer \
#    && rm -f /tmp/endpoint-security.tar.gz \
#    && rm -f /opt/Elastic/Endpoint/elastic-endpoint.yaml

## Host ID Prep
#RUN apt-get update -y && apt-get install -y dbus-tests
RUN apt-get update -y \
    && apt-get upgrade -y \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        dbus-tests \
    && apt-get clean

COPY --chown=0:0 ./hostidgen.sh /usr/local/bin/hostidgen.sh

RUN chmod 755 /usr/local/bin/hostidgen.sh

#RUN dbus-uuidgen > /etc/machine-id
#RUN apt purge dbus-tests -y


RUN set -e ; \
  apt-get install wget -y \
    && wget "https://github.com/elastic/apm-agent-php/releases/download/v${PHP_AGENT_VER}/apm-agent-php_${PHP_AGENT_VER}_all.deb" \
    && dpkg -i ./apm-agent-php_${PHP_AGENT_VER}_all.deb && rm apm-agent-php_${PHP_AGENT_VER}_all.deb && apt purge wget -y


# Configure PHP
RUN set -eux \
        && { \
                echo "allow_url_include = on"; \
                echo "allow_url_fopen   = on"; \
                echo "error_reporting   = E_ALL | E_STRICT"; \
                echo "magic_quotes_gpc  = off"; \
        } > /usr/local/etc/php/conf.d/default.ini

# Adjust permissions
RUN set -eux \
        && chown -R www-data:www-data /var/www/html \
        && chmod 0775 /var/www/html/config/ \
        && chmod 0775 /var/www/html/hackable/uploads/

# Recreate access and error log files to stop redirection
# to stderr and stdout and enable local agent to capture it
RUN set -eux \
        && rm /var/log/apache2/access.log \
        && rm /var/log/apache2/error.log \
        && touch /var/log/apache2/access.log \
        && touch /var/log/apache2/error.log \
        && chown -R www-data:www-data /var/log/apache2/

# Enable the substitute module to load the JS Agent dynamically
# Re-use the same ENV vars for the PHP Agent
RUN set -eux \
        && cp /etc/apache2/mods-available/substitute.load /etc/apache2/mods-enabled/ \
        && sed -i "19s/$/        AddOutputFilterByType SUBSTITUTE text\/html\n        Substitute \"s\#<\/head>\#<script src='\/js\/elastic-apm.umd.min.js'><\/script><script>elasticApm.init(\{serviceName: '\${ELASTIC_APM_SERVICE_NAME}-frontend',serverUrl: '\${ELASTIC_APM_SERVER_URL}',\})<\/script><\/head>\#inq\"/" /etc/apache2/sites-enabled/000-default.conf

CMD ["/usr/bin/tini", "--", "/usr/local/bin/docker-entrypoint"]
