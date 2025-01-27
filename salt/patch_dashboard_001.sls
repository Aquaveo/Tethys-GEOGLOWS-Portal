{% set TETHYS_PERSIST = salt['environ.get']('TETHYS_PERSIST') %}
{% set TETHYS_DB_HOST = salt['environ.get']('TETHYS_DB_HOST') %}
{% set POSTGRES_PASSWORD = salt['environ.get']('POSTGRES_PASSWORD') %}


PATCH_COUNTRIES_Database:
    cmd.run:
        - name: > 
            PGPASSWORD={{ POSTGRES_PASSWORD }} psql -U postgres -h {{ TETHYS_DB_HOST }} -d geoglows_dashboard_primary_db -c "DROP TABLE countries;"
        - shell: /bin/bash
        - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/patch_001_geoglows_dashboard_complete" ];"

PATCH_COUNTRIES_SYNC_Database:
    cmd.run:
        - name: > 
            tethys syncstores geoglows_dashboard
        - shell: /bin/bash
        - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/patch_001_geoglows_dashboard_complete" ];"

Flag_PATCH_COUNTRIES_Database_Complete:
  cmd.run:
    - name: touch {{ TETHYS_PERSIST }}/patch_001_geoglows_dashboard_complete
    - shell: /bin/bash
    - unless: /bin/bash -c "[ -f "{{ TETHYS_PERSIST }}/patch_001_geoglows_dashboard_complete" ];"