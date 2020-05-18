#!/bin/bash -x
# Builds an ARA API server container image using the latest PyPi packages on CentOS 8.
build=$(buildah from centos:8)

# Get all updates, install pip, database backends and gunicorn application server
# This lets users swap easily from the sqlite default to mysql or postgresql just by tweaking settings.yaml.
# Note: We use the packaged versions of psycopg2 and mysql python libraries so
#       we don't need to install development libraries before installing them from PyPi.
buildah run "${build}" -- /bin/bash -c "dnf update -y && dnf install -y epel-release && dnf install -y python3-pip python3-gunicorn python3-psycopg2 && dnf clean all"

# Install PyMySQL from pypi as not yet packaged for epel8
buildah run "${build}" -- /bin/bash -c "pip3 install PyMySQL"

# Install ara from source with API server extras for dependencies (django & django-rest-framework)
buildah run "${build}" -- /bin/bash -c "pip3 install ara[server]"

# Set up the container to execute SQL migrations and run the API server with gunicorn
buildah config --env ARA_BASE_DIR=/opt/ara "${build}"
buildah config --cmd "bash -c '/usr/local/bin/ara-manage migrate && /usr/bin/gunicorn-3 --workers=4 --access-logfile - --bind 0.0.0.0:8000 ara.server.wsgi'" "${build}"
buildah config --port 8000 "${build}"

# Commit this container to an image name
buildah commit "${build}" "${1:-$USER/ara-api}"
