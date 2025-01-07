FROM tethysplatform/tethys-core:dev-py3.10-dj3.2 as base

ARG MAMBA_DOCKERFILE_ACTIVATE=1

#############
# ADD FILES #
#############

COPY apps ${TETHYS_HOME}/apps
COPY requirements/*.txt .

########################
# INSTALL APPLICATIONS #
########################
RUN micromamba install --yes -c conda-forge --file requirements.txt && \
    micromamba install --yes -c conda-forge numpy==1.26.4 && \
    cd ${TETHYS_HOME}/apps/tethysapp-geoglows_dashboard && tethys install -w -N -q && \
    cd ${TETHYS_HOME}/apps/ggst && tethys install -w -N -q && \
    cd ${TETHYS_HOME}/apps/gwdm && tethys install -w -N -q

# Final Image Build
FROM tethysplatform/tethys-core:dev-py3.10-dj3.2 as build


ENV TETHYS_DOMAIN="localhost" 
ENV POSTGIS_SERVICE_NAME=""
ENV GS_SERVICE_NAME=""
ENV THREDDS_SERVICE_NAME=""
ENV POSTGRES_USER="postgres"
# example --> /var/lib/tethys_persist/thredds_data/tethys

ENV TETHYS_THREDDS_DATA_PATH=""

ENV GWDM_WORKSPACE_NAME="gwdm"
ENV GWDM_STORE_NAME="gwdm"
ENV GWDM_TABLE_NAME="gwdm_gwdb"
ENV GWDM_REGION_LAYER_NAME="region"
ENV GWDM_AQUIFER_LAYER_NAME="aquifer"
ENV GWDM_WELL_LAYER_NAME="well"

# example --> gwdm_data_directory
ENV GWDM_CS_DATA_DIRECTORY=""

# example --> gwdm_thredds_directory
ENV GWDM_CS_THREDDS_DIRECTORY=""
# example --> /thredds/catalog/data/tethys/gwdm_thredds_directory/catalog.xml
ENV GWDM_CS_THREDDS_CATALOG_SUBPATH=""

# example --> ggst_thredds_directory
ENV GGST_CS_THREDDS_DIRECTORY=""
# example --> /thredds/catalog/data/tethys/ggst_thredds_directory/catalog.xml
ENV GGST_CS_THREDDS_CATALOG_SUBPATH=""


# example --> /usr/lib/tethys
ENV GGST_CS_GLOBAL_OUTPUT_DIRECTORY=""

ENV GGST_CS_EARTHDATA_USERNAME=""
ENV GGST_CS_EARTHDATA_PASS=""  
ENV GGST_CS_CONDA_PYTHON_PATH="/opt/conda/envs/tethys/bin/python"

ENV TETHYS_GS_PORT="8181"
ENV TETHYS_GS_HOST=""
ENV TETHYS_GS_PASSWORD="geoserver"
ENV TETHYS_GS_USERNAME="admin"
ENV TETHYS_GS_PROTOCOL=""
ENV TETHYS_GS_HOST_PUB=""
ENV TETHYS_GS_PORT_PUB=""
ENV TETHYS_GS_PROTOCOL_PUB=""

COPY --chown=www:www --from=base ${CONDA_HOME}/envs/${CONDA_ENV_NAME} ${CONDA_HOME}/envs/${CONDA_ENV_NAME}
COPY config/apps/post_setup_gwdm.py ${TETHYS_HOME}
COPY salt/ /srv/salt/

ARG MAMBA_DOCKERFILE_ACTIVATE=1

RUN rm -Rf ~/.cache/pip && \
    micromamba clean --all --yes

EXPOSE 80
CMD bash run.sh