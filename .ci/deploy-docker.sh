#!/bin/sh
set -euf
cd "$(dirname "${0}")/.."
# tag="${TAG#v}"

printf '%s\n' "${DOCKER_PASSWORD}" | docker login --username "${DOCKER_USERNAME}" --password-stdin
docker build --tag 'azlint' .

# docker tag 'azlint' "matejkosiarcik/azlint:${tag}"
# docker push "matejkosiarcik/azlint:${tag}"

docker tag 'azlint' "matejkosiarcik/azlint:latest"
docker push "matejkosiarcik/azlint:latest"
