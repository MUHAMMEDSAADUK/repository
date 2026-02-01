# Builds on official Odoo image and installs wkhtmltopdf & useful dev packages
FROM odoo:16.0

USER root

# Install packages required for wkhtmltopdf and development convenience
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
       wkhtmltopdf \
       xfonts-75dpi \
       xfonts-base \
       git \
       curl \
       vim \
  && rm -rf /var/lib/apt/lists/*

# Ensure correct ownership for mounted addons (odoo user uid in official image is 1000)
RUN mkdir -p /mnt/extra-addons && chown -R 1000:1000 /mnt/extra-addons

USER odoo

# Keep default entrypoint from base image; the base image runs odoo
