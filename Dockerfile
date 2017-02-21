FROM quay.io/nordstrom/python:2.7

MAINTAINER Innovation Platform Team "invcldtm@nordstrom.com"

USER 0


# Elastalert home directory full path.
# Elastalert rules directory.
# Elastalert configuration file path in configuration directory.
# Elasticsearch address (defaults to openshift EFK-stack)
ENV ELASTALERT_HOME=/opt/elastalert \
    ELASTALERT_CONFIG=/opt/elastalert/config.yaml \
    RULES_DIRECTORY=/rules \
    ELASTICSEARCH_HOST=logging-es.logging \
    ELASTICSEARCH_PORT=9200 \
    USE_SSL=true

VOLUME [ "${RULES_DIRECTORY}" ]

# Install curl
RUN apt-get update && apt-get install -y \
    unzip \ 
    python-dev \
    gcc
#    musl-dev

# Download and unpack Elastalert.
RUN curl -L -o elastalert.zip https://github.com/sterburg/elastalert/archive/master.zip && \
    unzip *.zip && \
    rm *.zip && \
    mv elast* ${ELASTALERT_HOME}

WORKDIR ${ELASTALERT_HOME}

# Install Elastalert.
RUN pip install --upgrade pip
RUN pip install --ignore-installed setuptools
RUN pip install --ignore-installed --upgrade -r requirements.txt
RUN pip install --upgrade tzlocal
RUN pip install --upgrade datetime
RUN python ./setup.py install

# Create rules directories. 
RUN mkdir -m 0777 -p ${RULES_DIRECTORY} && \
    mkdir -p elastalert/elastalert_modules

COPY ./__init__.py                elastalert/elastalert_modules/__init__.py
COPY ./prometheus_alertmanager.py elastalert/elastalert_modules/prometheus_alertmanager.py
COPY ./example_rule.yaml          /rules/example_rule.yaml
COPY config.yaml                  /opt/elastalert/config.yaml
COPY start-elastalert.sh          /opt/elastalert/start-elastalert.sh

# Make the start-script executable.
RUN chmod +x start-elastalert.sh
RUN chmod -R ugo+rwX ${ELASTALERT_HOME} ${RULES_DIRECTORY} ${ELASTALERT_CONFIG} /etc/ssl 

USER ubuntu

# Launch Elastalert when a container is started.
ENTRYPOINT [ "/opt/elastalert/start-elastalert.sh" ]
CMD ["python", "-m", "elastalert.elastalert", "--config", "config.yaml", "--verbose", "--debug", "--es_debug"]
