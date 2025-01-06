{% set DATA_FILE_DESTINATION = '/var/www/tethys/apps/tethysapp-geoglows_dashboard/tethysapp/geoglows_dashboard/workspaces/app_workspaces/hydrosos/streamflow/vpu_122' %}
{% set DATA_FILE_URL = 'https://geoglows-dashboard-data.s3.us-east-2.amazonaws.com/combined_all_data_122.nc' %}
{% set TETHYS_PERSIST = salt['environ.get']('TETHYS_PERSIST') %}



EnsureDirectoryExists:
  file.directory:
    - name: /var/www/tethys/apps/tethysapp-geoglows_dashboard/tethysapp/geoglows_dashboard/workspaces/app_workspaces/hydrosos/streamflow/vpu_122
    - mode: 755
    - makedirs: True

VerifyFile:
  cmd.run:
    - name: ls -la /var/www/tethys/apps/tethysapp-geoglows_dashboard/tethysapp/geoglows_dashboard/workspaces/app_workspaces/hydrosos/streamflow/vpu_122
    - require:
      - file: EnsureDirectoryExists

DownloadFile: 
    cmd.run:
        - name: wget -O {{ DATA_FILE_DESTINATION }}/combined_all_data_122.nc {{ DATA_FILE_URL }}
        - shell: /bin/bash
        - require:
            - file: /var/www/tethys/apps/tethysapp-geoglows_dashboard/tethysapp/geoglows_dashboard/workspaces/app_workspaces/hydrosos/streamflow/vpu_122




Initiate_Geoserver:
    cmd.run: 
        - name: "tethys manage shell < /var/www/tethys/apps/tethysapp-geoglows_dashboard/tethysapp/geoglows_dashboard/init_geoserver.py"
        - shell: /bin/bash
        - cwd: /var/www/tethys/apps/tethysapp-geoglows_dashboard/tethysapp/geoglows_dashboard
        - stream: True
        - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/init_geoserver_complete" ];"

Flag_Init_Geoserver_Complete:
  cmd.run:
    - name: touch {{ TETHYS_PERSIST }}/init_geoserver_complete
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/init_geoserver_complete" ];"
    - require:
      - cmd: Initiate_Geoserver



Initiate_River_Tables:
    cmd.run: 
        - name: "tethys manage shell < /var/www/tethys/apps/tethysapp-geoglows_dashboard/tethysapp/geoglows_dashboard/init_database.py"
        - shell: /bin/bash
        - cwd: /var/www/tethys/apps/tethysapp-geoglows_dashboard/tethysapp/geoglows_dashboard
        - stream: True
        - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/tethys_river_tables_complete" ];"

Flag_Init_River_Tables_Complete:
  cmd.run:
    - name: touch {{ TETHYS_PERSIST }}/init_river_tables_complete
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/init_river_tables_complete" ];" 
    - require:
      - cmd: Initiate_River_Tables
