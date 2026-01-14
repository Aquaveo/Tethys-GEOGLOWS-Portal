FROM tethysplatform/tethys-core:dev-py3.11-dj4.2 as base

ARG MAMBA_DOCKERFILE_ACTIVATE=1
ARG TETHYS_PORTAL_HOST=""
ARG TETHYS_APP_ROOT_URL="/apps/tethysdash/"
ARG TETHYS_LOADER_DELAY="500"
ARG TETHYS_DEBUG_MODE="false"

ENV TETHYS_DOMAIN="localhost"
ENV TETHYS_THREDDS_PROTOCOL="http"
ENV POSTGIS_SERVICE_NAME="primary_postgis"
ENV GS_SERVICE_NAME="primary_geoserver"
ENV THREDDS_SERVICE_NAME="primary_thredds"
ENV POSTGRES_USER="postgres"
ENV TETHYS_THREDDS_DATA_PATH="/var/lib/tethys_persist/data" 

ENV GGST_CS_THREDDS_DIRECTORY="ggst"
ENV GGST_CS_THREDDS_CATALOG_SUBPATH="/thredds/catalog/data/thredds_data/ggst/catalog.xml"
ENV GGST_CS_GLOBAL_OUTPUT_DIRECTORY="ggst_global_output"
ENV GGST_CS_CONDA_PYTHON_PATH="/opt/conda/envs/tethys/bin/python"
ENV GGST_CS_EARTHDATA_USERNAME=""
ENV GGST_CS_EARTHDATA_PASS=""  

ENV TETHYS_GS_PORT="8181"
ENV TETHYS_GS_PORT_PUB="8181"
ENV TETHYS_GS_PASSWORD="geoserver"
ENV TETHYS_GS_USERNAME="admin"
ENV TETHYS_GS_PROTOCOL="http"
ENV TETHYS_GS_PROTOCOL_PUB="http"
ENV TETHYS_GS_HOST=""
ENV TETHYS_GS_HOST_PUB=""

ENV THREDDS_TDS_USERNAME="admin"
ENV THREDDS_TDS_PASSWORD="tdm_pass"
ENV THREDDS_TDS_CATALOG="/thredds/catalog/data/catalog.xml"
ENV THREDDS_TDS_PRIVATE_PROTOCOL="http"
ENV THREDDS_TDS_PRIVATE_PORT="8080"
ENV THREDDS_TDS_PUBLIC_PROTOCOL="http"
ENV THREDDS_TDS_PUBLIC_PORT="8080"
ENV THREDDS_TDS_PUBLIC_HOST=""
ENV THREDDS_TDS_PRIVATE_HOST=""


ENV TETHYS_DASH_APP_SRC_ROOT=${TETHYS_HOME}/apps/tethysdash
ENV DEV_REACT_CONFIG="${TETHYS_DASH_APP_SRC_ROOT}/reactapp/config/development.env"
ENV PROD_REACT_CONFIG="${TETHYS_DASH_APP_SRC_ROOT}/reactapp/config/production.env"
ENV NVM_DIR=/usr/local/nvm
ENV NODE_VERSION=20.12.2
ENV NODE_VERSION_DIR=${NVM_DIR}/versions/node/v${NODE_VERSION}
ENV NODE_PATH=${NODE_VERSION_DIR}/lib/node_modules
ENV PATH=${NODE_VERSION_DIR}/bin:$PATH
ENV NPM=${NODE_VERSION_DIR}/bin/npm

COPY apps ${TETHYS_HOME}/apps
COPY plugins ${TETHYS_HOME}
COPY requirements/*.txt .
COPY images/firo_dash_default_dashboard.png ${TETHYS_HOME}/apps/tethysdash/tethysapp/tethysdash/default_dashboard.png
COPY images/firo_dash_logo.png ${TETHYS_HOME}/apps/tethysdash/tethysapp/tethysdash/public/images/tethys_dash.png

RUN mkdir -p ${NVM_DIR} \
  && curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | /bin/bash \
  && . ${NVM_DIR}/nvm.sh \
  && nvm install ${NODE_VERSION} \
  && nvm alias default ${NODE_VERSION} \
  && nvm use default



########################
# INSTALL APPLICATIONS #
########################
RUN micromamba install --yes -c conda-forge --file requirements.txt \
    && micromamba install --yes -c conda-forge numpy==1.26.4 \
    && mv ${DEV_REACT_CONFIG} ${PROD_REACT_CONFIG} \
    && sed -i "s#TETHYS_DEBUG_MODE.*#TETHYS_DEBUG_MODE = ${TETHYS_DEBUG_MODE}#g" ${PROD_REACT_CONFIG} \
    && sed -i "s#TETHYS_LOADER_DELAY.*#TETHYS_LOADER_DELAY = ${TETHYS_LOADER_DELAY}#g" ${PROD_REACT_CONFIG} \
    && sed -i "s#TETHYS_PORTAL_HOST.*#TETHYS_PORTAL_HOST = ${TETHYS_PORTAL_HOST}#g" ${PROD_REACT_CONFIG} \
    && sed -i "s#TETHYS_APP_ROOT_URL.*#TETHYS_APP_ROOT_URL = ${TETHYS_APP_ROOT_URL}#g" ${PROD_REACT_CONFIG} \
    && cd ${TETHYS_HOME}/apps/tethysdash && npm install && npm run build && tethys install -w -N -q \
    && cd ${TETHYS_HOME}/plugins/geoglows \
    && pip install --no-cache-dir --quiet . \
    && cd ${TETHYS_HOME}/apps/ggst && tethys install -w -N -q



FROM tethysplatform/tethys-core:dev-py3.11-dj4.2 as build

COPY --chown=www:www --from=base ${CONDA_HOME}/envs/${CONDA_ENV_NAME} ${CONDA_HOME}/envs/${CONDA_ENV_NAME}
COPY salt/ /srv/salt/
COPY config/thredds/setup-thredds-config.sh ${TETHYS_HOME}
# Activate tethys conda environment during build
ARG MAMBA_DOCKERFILE_ACTIVATE=1

RUN rm -Rf ~/.cache/pip && \
    micromamba clean --all --yes && \
    mkdir -p -m 777 ${TETHYS_PERSIST}/data/tethysdash \
    && cd ${TETHYS_HOME}/ext/tethysext-default_theme \
    && pip install --no-cache-dir --quiet . \
    && chmod -R 777 ${CONDA_HOME}/envs/${CONDA_ENV_NAME}

EXPOSE 80
WORKDIR ${TETHYS_HOME}
CMD bash -c "salt-call --local state.apply -l info | tee /var/log/salt.log && bash run.sh"

