{% set TETHYS_HOME = salt['environ.get']('TETHYS_HOME') %}
{% set TETHYS_PERSIST = salt['environ.get']('TETHYS_PERSIST') %}

{% set GEOGLOWS_DASHBOARD_PATH = salt['environ.get']('GEOGLOWS_DASHBOARD_PATH') %}



Link_all_Data_File:
    cmd.run: 
        - name: "ln -s {{ TETHYS_HOME }}/routing-configs {{ GEOGLOWS_DASHBOARD_PATH }}/workspaces/app_workspace/hydrosos/streamflow/routing-configs"
        - shell: /bin/bash

Link_all_Data_File2:
    cmd.run: 
        - name: "ln -s {{ TETHYS_HOME }}/routing-configs {{ TETHYS_PERSIST }}/workspaces/geoglows_dashboard/app_workspace/hydrosos/streamflow/routing-configs"
        - shell: /bin/bash
