FROM tethysplatform/tethys-core:dev-py3.12-dj3.2

ARG MAMBA_DOCKERFILE_ACTIVATE=1

#############
# ADD FILES #
#############

COPY apps ${TETHYS_HOME}/apps
COPY requirements/*.txt .

########################
# INSTALL APPLICATIONS #
########################
RUN pip install --no-cache-dir --quiet -r piprequirements.txt && \
    micromamba install --yes -c conda-forge --file requirements.txt && \
    micromamba clean --all --yes && \
    cd ${TETHYS_HOME}/apps/tethysapp-geoglows_dashboard && tethys install -w -N -q && \
    cd ${TETHYS_HOME}/apps/ggst && tethys install -w -N -q && \
    cd ${TETHYS_HOME}/apps/gwdm && tethys install -w -N -q

# Final Image Build
FROM tethysplatform/tethys-core:dev-py3.12-dj3.2 as build


ENV TETHYS_DOMAIN = "localhost" 
ENV TETHYS_THREDDS_DATA_PATH="/var/lib/tethys_persist/thredds_data/tethys"

ENV GWDM_WORKSPACE_NAME="gwdm"
ENV GWDM_STORE_NAME="gwdm"
ENV GWDM_TABLE_NAME="gwdm_gwdb"
ENV GWDM_REGION_LAYER_NAME="region"
ENV GWDM_AQUIFER_LAYER_NAME="aquifer"
ENV GWDM_WELL_LAYER_NAME="well"
ENV GWDM_CS_DATA_DIRECTORY="gwdm_data_directory"
ENV GWDM_CS_THREDDS_DIRECTORY="gwdm_thredds_directory"
ENV GWDM_CS_THREDDS_CATALOG_SUBPATH="/thredds/catalog/data/tethys/gwdm_thredds_directory/catalog.xml"

ENV GGST_CS_THREDDS_DIRECTORY="ggst_thredds_directory"
ENV GGST_CS_THREDDS_CATALOG_SUBPATH="/thredds/catalog/data/tethys/ggst_thredds_directory/catalog.xml"
ENV GGST_CS_GLOBAL_OUTPUT_DIRECTORY="/usr/lib/tethys"
# This is an example username for the EarthData login
ENV GGST_CS_EARTHDATA_USERNAME="admin"  
# This is an example password for the EarthData login
ENV GGST_CS_EARTHDATA_PASS="pass"  
ENV GGST_CS_CONDA_PYTHON_PATH="/opt/conda/envs/tethys/bin/python"

ENV TETHYS_GS_PORT="8181"
ENV TETHYS_GS_HOST=""
ENV TETHYS_GS_PASSWORD="geoserver"
ENV TETHYS_GS_USERNAME="admin"
ENV TETHYS_GS_PROTOCOL=""
ENV TETHYS_GS_HOST_PUB=""
ENV TETHYS_GS_PORT_PUB=""
ENV TETHYS_GS_PROTOCOL_PUB=""
ENV TETHYS_GS_URL=""
ENV TETHYS_GS_URL_PUB=""
ENV GS_SERVICE_NAME="primary_geoserver"


COPY config/apps/post_setup_gwdm.py ${TETHYS_HOME}

COPY salt/ /srv/salt/

ARG MAMBA_DOCKERFILE_ACTIVATE=1

RUN rm -Rf ~/.cache/pip && \
    micromamba clean --all --yes

EXPOSE 80
CMD bash run.sh