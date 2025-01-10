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
    cd ${TETHYS_HOME}/apps/tethysapp-geoglows_dashboard && tethys install -w -N -q && \
    cd ${TETHYS_HOME}/apps/ggst && tethys install -w -N -q && \
    cd ${TETHYS_HOME}/apps/gwdm && tethys install -w -N -q
    

# Final Image Build
FROM tethysplatform/tethys-core:dev-py3.10-dj3.2 as build


ENV TETHYS_DOMAIN="localhost"
ENV TETHYS_THREDDS_PROTOCOL="http"
ENV POSTGIS_SERVICE_NAME="primary_postgis"
ENV GS_SERVICE_NAME="primary_geoserver"
ENV THREDDS_SERVICE_NAME="primary_thredds"
ENV POSTGRES_USER="postgres"
ENV TETHYS_THREDDS_DATA_PATH="/var/lib/tethys_persist/data" 

ENV GEOGLOWS_DASHBOARD_PATH="/opt/conda/envs/tethys/lib/python3.10/site-packages/tethysapp/geoglows_dashboard"

ENV GWDM_WORKSPACE_NAME="gwdm"
ENV GWDM_STORE_NAME="gwdm"
ENV GWDM_TABLE_NAME="gwdm_gwdb"
ENV GWDM_REGION_LAYER_NAME="region"
ENV GWDM_AQUIFER_LAYER_NAME="aquifer"
ENV GWDM_WELL_LAYER_NAME="well"

ENV GWDM_CS_DATA_DIRECTORY="gwdm_data_directory"
ENV GWDM_CS_THREDDS_DIRECTORY="gwdm_thredds_directory"
ENV GWDM_CS_THREDDS_CATALOG_SUBPATH="/thredds/catalog/data/gwdm_thredds_directory/catalog.xml"
ENV GGST_CS_THREDDS_DIRECTORY="ggst_thredds_directory"
ENV GGST_CS_THREDDS_CATALOG_SUBPATH="/thredds/catalog/data/ggst_thredds_directory/catalog.xml"
ENV GGST_CS_GLOBAL_OUTPUT_DIRECTORY="/usr/lib/tethys"
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



COPY --chown=www:www --from=base ${CONDA_HOME}/envs/${CONDA_ENV_NAME} ${CONDA_HOME}/envs/${CONDA_ENV_NAME}
COPY config/apps/post_setup_gwdm.py ${TETHYS_HOME}
COPY salt/ /srv/salt/

ARG MAMBA_DOCKERFILE_ACTIVATE=1

RUN rm -Rf ~/.cache/pip && \
    micromamba install --yes -c conda-forge numpy==1.26.4 && \
    micromamba clean --all --yes

EXPOSE 80
CMD bash -c "salt-call --local state.apply -l info | tee /var/log/salt.log && bash run.sh"
