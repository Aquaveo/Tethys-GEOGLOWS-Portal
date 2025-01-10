{% set TETHYS_PERSIST = salt['environ.get']('TETHYS_PERSIST') %}
{% set TETHYS_HOME = salt['environ.get']('TETHYS_HOME') %}


{% set TETHYS_DB_HOST = salt['environ.get']('TETHYS_DB_HOST') %}
{% set TETHYS_DB_PORT = salt['environ.get']('TETHYS_DB_PORT') %}
{% set TETHYS_DB_SUPERUSER = salt['environ.get']('TETHYS_DB_SUPERUSER') %}
{% set TETHYS_DB_SUPERUSER_PASS = salt['environ.get']('TETHYS_DB_SUPERUSER_PASS') %}

{% set TETHYS_DB_USERNAME = salt['environ.get']('TETHYS_DB_USERNAME') %}
{% set TETHYS_DB_PASS = salt['environ.get']('TETHYS_DB_PASS') %}

{% set POSTGIS_SERVICE_URL = TETHYS_DB_SUPERUSER + ':' + TETHYS_DB_SUPERUSER_PASS + '@' + TETHYS_DB_HOST + ':' + TETHYS_DB_PORT %}

{% set TETHYS_GS_HOST = salt['environ.get']('TETHYS_GS_HOST') %}
{% set TETHYS_GS_PASSWORD = salt['environ.get']('TETHYS_GS_PASSWORD') %}
{% set TETHYS_GS_PORT = salt['environ.get']('TETHYS_GS_PORT') %}
{% set TETHYS_GS_USERNAME = salt['environ.get']('TETHYS_GS_USERNAME') %}
{% set TETHYS_GS_PROTOCOL = salt['environ.get']('TETHYS_GS_PROTOCOL') %}
{% set TETHYS_GS_HOST_PUB = salt['environ.get']('TETHYS_GS_HOST_PUB') %}
{% set TETHYS_GS_PORT_PUB = salt['environ.get']('TETHYS_GS_PORT_PUB') %}
{% set TETHYS_GS_PROTOCOL_PUB = salt['environ.get']('TETHYS_GS_PROTOCOL_PUB') %}
{% set TETHYS_GS_URL = TETHYS_GS_PROTOCOL +'://' + TETHYS_GS_USERNAME + ':' + TETHYS_GS_PASSWORD + '@' + TETHYS_GS_HOST + ':' + TETHYS_GS_PORT %}
{% set TETHYS_GS_URL_PUB = TETHYS_GS_PROTOCOL_PUB +'://' + TETHYS_GS_USERNAME + ':' + TETHYS_GS_PASSWORD + '@' + TETHYS_GS_HOST_PUB + ':' + TETHYS_GS_PORT_PUB %}

{% set APPLICATION_PATH = salt['environ.get']('GEOGLOWS_DASHBOARD_PATH') %}


{% set POSTGIS_SERVICE_NAME = salt['environ.get']('POSTGIS_SERVICE_NAME') %}
{% set GS_SERVICE_NAME = salt['environ.get']('GS_SERVICE_NAME') %}

{% set DATA_FILE_DESTINATION = APPLICATION_PATH + '/workspaces/app_workspaces/hydrosos/streamflow/vpu_122' %}
{% set DATA_FILE_URL = 'https://geoglows-dashboard-data.s3.us-east-2.amazonaws.com/combined_all_data_122.nc' %}



Geoglows_Dashboard_Link_PostGIS_Database_Service:
    cmd.run:
        - name: "tethys link persistent:{{ POSTGIS_SERVICE_NAME }} geoglows_dashboard:ps_database:primary_db"
        - shell: /bin/bash
        - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/tethys_services_complete" ];"

Geoglows_Dashboard_Sync_Persistent_Stores:
    cmd.run:
        - name: tethys syncstores geoglows_dashboard
        - shell: /bin/bash
        - unless: /bin/bash -c "[ -f "${TETHYS_PERSIST}/tethys_services_complete" ];"

Geoglows_Dashboard_Link_Spatial__Dataset_Service:
    cmd.run:
        - name: "tethys link spatial:{{ GS_SERVICE_NAME }} geoglows_dashboard:ds_spatial:{{ GS_SERVICE_NAME}}"
        - shell: /bin/bash
        - unless: /bin/bash -c "[ -f "${TETHYS_PERSIST}/tethys_services_complete" ];"

EnsureDirectoryExists:
  file.directory:
    - name: {{ DATA_FILE_DESTINATION }}
    - mode: 755
    - makedirs: True

VerifyFile:
  cmd.run:
    - name: ls -la {{ DATA_FILE_DESTINATION }}
    - require:
      - file: EnsureDirectoryExists

# DownloadFile: 
#     cmd.run:
#         - name: wget -O {{ DATA_FILE_DESTINATION }}/combined_all_data_122.nc {{ DATA_FILE_URL }}
#         - shell: /bin/bash
#         - require:
#             - file: {{ DATA_FILE_DESTINATION }}

Initiate_Geoserver:
    cmd.run: 
        - name: "tethys manage shell < {{ APPLICATION_PATH }}/init_geoserver.py"
        - shell: /bin/bash
        - cwd: {{ APPLICATION_PATH }}
        - stream: True
        - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/init_geoserver_complete" ];"


Initiate_River_Tables:
    cmd.run: 
        - name: "tethys manage shell < {{ APPLICATION_PATH }}/init_database.py"
        - shell: /bin/bash
        - cwd: {{ APPLICATION_PATH }}
        - stream: True
        - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/tethys_river_tables_complete" ];"

Geoglows_Dashboard_Flag_Complete:
  cmd.run:
    - name: touch {{ TETHYS_PERSIST }}/init_river_tables_complete
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/geoglows_dashboard_complete" ];" 
    - require:
      - cmd: geoglows_dashboard_complete
