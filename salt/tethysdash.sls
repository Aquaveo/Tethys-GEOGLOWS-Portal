{% set TETHYS_PERSIST = salt['environ.get']('TETHYS_PERSIST') %}
{% set TETHYS_HOME = salt['environ.get']('TETHYS_HOME') %}
{% set POSTGIS_SERVICE_NAME = salt['environ.get']('POSTGIS_SERVICE_NAME') %}
Link_PostGIS_To_TethysDash:
  cmd.run:
    - name: "tethys link persistent:{{ POSTGIS_SERVICE_NAME }} tethysdash:ps_database:primary_db"
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/tethysdash_setup_complete" ];"


Sync_TethysDash_Persistent_Stores:
  cmd.run:
    - name: tethys syncstores tethysdash
    - shell: /bin/bash


Collect_TethysDash_Plugin_Metadata:
  cmd.run:
  - name: |
      SCRIPT_DIR=$(dirname $(python -c 'import tethysapp.tethysdash as m; print(m.__file__)'))
      cd $SCRIPT_DIR
      python collect_plugin_static.py
  - shell: /bin/bash
  - cwd: /

Flag_TethysDash_Setup_Complete:
  cmd.run:
    - name: touch {{ TETHYS_PERSIST }}/tethysdash_setup_complete
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/tethysdash_setup_complete" ];"