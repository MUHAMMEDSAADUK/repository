# Dockerfile for building Odoo 19 (development-friendly)
ARG ODOO_VERSION=19.0
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    ODOO_USER=odoo \
    ODOO_HOME=/opt/odoo \
    PYTHONUNBUFFERED=1

# Install base packages and dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl wget git gcc g++ make python3 python3-venv python3-dev \
    build-essential libpq-dev libxml2-dev libxslt1-dev libjpeg-dev libfreetype6-dev \
    liblcms2-dev libblas-dev libatlas-base-dev libsasl2-dev libldap2-dev libssl-dev \
    nodejs npm npm-check-updates xz-utils libffi-dev locales python3-wheel gdebi-core \
    freetype* && \
    # set locale
    locale-gen en_US.UTF-8 && \
    rm -rf /var/lib/apt/lists/*

# Create odoo user
RUN useradd -m -U -r -s /bin/bash ${ODOO_USER}

# Install wkhtmltopdf (static build recommended)
# Using wkhtmltopdf 0.12.6 (adjust if newer recommended build exists)
RUN WK_PACKAGE="wkhtmltox_0.12.6-1.focal_amd64.deb" && \
    curl -fsSL -o /tmp/$WK_PACKAGE "https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.6/$WK_PACKAGE" && \
    apt-get update && apt-get install -y /tmp/$WK_PACKAGE || true && \
    rm -f /tmp/$WK_PACKAGE && rm -rf /var/lib/apt/lists/*

# Switch to /opt and clone Odoo
WORKDIR /opt
RUN git clone --depth 1 --branch ${ODOO_VERSION} https://github.com/odoo/odoo.git ${ODOO_HOME} && \
    chown -R ${ODOO_USER}:${ODOO_USER} ${ODOO_HOME}

# Create Python venv and install requirements
USER ${ODOO_USER}
RUN python3 -m venv ${ODOO_HOME}/venv && \
    ${ODOO_HOME}/venv/bin/pip install --upgrade pip wheel setuptools && \
    if [ -f ${ODOO_HOME}/requirements.txt ]; then \
      ${ODOO_HOME}/venv/bin/pip install -r ${ODOO_HOME}/requirements.txt; \
    fi

# Expose Odoo ports
EXPOSE 8069 8072

# Volumes and config
VOLUME ["/var/lib/odoo", "/mnt/extra-addons"]
ENV PATH="${ODOO_HOME}/venv/bin:${PATH}" \
    ODOO_RC=/etc/odoo/odoo.conf

# Copy default config (if user binds config/odoo.conf it will override)
USER root
COPY ./config/odoo.conf ${ODOO_HOME}/odoo.conf.sample
RUN mkdir -p /etc/odoo /var/log/odoo && \
    chown -R ${ODOO_USER}:${ODOO_USER} /etc/odoo /var/log/odoo

USER ${ODOO_USER}
# Default command: run odoo with the provided config file
CMD ["bash", "-c", "${ODOO_HOME}/venv/bin/python ${ODOO_HOME}/odoo-bin -c ${ODOO_RC}"]