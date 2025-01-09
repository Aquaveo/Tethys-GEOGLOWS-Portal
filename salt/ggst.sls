{% set TETHYS_PERSIST = salt['environ.get']('TETHYS_PERSIST') %}

{% set TETHYS_THREDDS_DATA_PATH = salt['environ.get']('TETHYS_THREDDS_DATA_PATH') %}

{% set GGST_CS_THREDDS_DIRECTORY = salt['environ.get']('GGST_CS_THREDDS_DIRECTORY') %}
{% set GGST_CS_GLOBAL_OUTPUT_DIRECTORY = salt['environ.get']('GGST_CS_GLOBAL_OUTPUT_DIRECTORY') %}

{% set GGST_CS_THREDDS_DIRECTORY_PATH = TETHYS_THREDDS_DATA_PATH + '/' + GGST_CS_THREDDS_DIRECTORY %}
{% set GGST_CS_GLOBAL_OUTPUT_DIRECTORY_PATH = TETHYS_THREDDS_DATA_PATH + '/' + GGST_CS_GLOBAL_OUTPUT_DIRECTORY %}

{% set TETHYS_DOMAIN = salt['environ.get']('TETHYS_DOMAIN') %}
{% set THREDDS_TDS_PUBLIC_PROTOCOL = salt['environ.get']('THREDDS_TDS_PUBLIC_PROTOCOL') %}
{% set GGST_CS_THREDDS_CATALOG_SUBPATH = salt['environ.get']('GGST_CS_THREDDS_CATALOG_SUBPATH') %}
{% set GGST_CS_THREDDS_CATALOG = THREDDS_TDS_PUBLIC_PROTOCOL + '://' + TETHYS_DOMAIN + GGST_CS_THREDDS_CATALOG_SUBPATH %}

{% set GGST_CS_EARTHDATA_USERNAME = salt['environ.get']('GGST_CS_EARTHDATA_USERNAME') %}
{% set GGST_CS_EARTHDATA_PASS = salt['environ.get']('GGST_CS_EARTHDATA_PASS') %}
{% set GGST_CS_CONDA_PYTHON_PATH = salt['environ.get']('GGST_CS_CONDA_PYTHON_PATH') %}

{% set DATA_FOLDER_URL = 'https://geoglows-dashboard-data.s3.us-east-2.amazonaws.com/thredds/ggst' %}


GGST_tHREDDS_Download_Data: 
    cmd.run:
        - name: wget -O {{ GGST_CS_THREDDS_DIRECTORY }} {{ DATA_FOLDER_URL }}
        - shell: /bin/bash
        - require:
            - file: {{ GGST_CS_THREDDS_DIRECTORY }}

Set_GGST_Settings:
  cmd.run:
    - name: > 
        tethys app_settings set ggst grace_thredds_directory {{ GGST_CS_THREDDS_DIRECTORY_PATH }} &&
        tethys app_settings set ggst grace_thredds_catalog {{ GGST_CS_THREDDS_CATALOG }} &&
        tethys app_settings set ggst global_output_directory {{ GGST_CS_GLOBAL_OUTPUT_DIRECTORY_PATH }} &&
        tethys app_settings set ggst earthdata_username {{ GGST_CS_EARTHDATA_USERNAME }} &&
        tethys app_settings set ggst earthdata_pass {{ GGST_CS_EARTHDATA_PASS }} &&
        tethys app_settings set ggst conda_python_path {{ GGST_CS_CONDA_PYTHON_PATH }}

    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "${TETHYS_PERSIST}/ggst_complete" ];"

Flag_Tethys_GGST_Setup_Complete:
  cmd.run:
    - name: touch {{ TETHYS_PERSIST }}/ggst_complete
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/ggst_complete" ];"