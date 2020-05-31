#!/bin/sh
set -euf

docker login || (printf '%s\n' "${DOCKER_PASSWORD}" | docker login --username "${DOCKER_USERNAME}" --password-stdin)

if [ "${AZLINT_VERSION}" != 'dev' ]; then
    docker tag 'matejkosiarcik/azlint:dev' "matejkosiarcik/azlint:${AZLINT_VERSION}"
    docker tag 'matejkosiarcik/azlint:internal-dev-alpine' "matejkosiarcik/azlint:internal-${AZLINT_VERSION}-alpine"
    docker tag 'matejkosiarcik/azlint:internal-dev-debian' "matejkosiarcik/azlint:internal-${AZLINT_VERSION}-debian"
    docker tag 'matejkosiarcik/azlint:internal-dev-python' "matejkosiarcik/azlint:internal-${AZLINT_VERSION}-python"
    docker tag 'matejkosiarcik/azlint:internal-dev-node' "matejkosiarcik/azlint:internal-${AZLINT_VERSION}-node"
    docker tag 'matejkosiarcik/azlint:internal-dev-composer' "matejkosiarcik/azlint:internal-${AZLINT_VERSION}-composer"
    docker tag 'matejkosiarcik/azlint:internal-dev-go' "matejkosiarcik/azlint:internal-${AZLINT_VERSION}-go"
    docker tag 'matejkosiarcik/azlint:internal-dev-shellcheck' "matejkosiarcik/azlint:internal-${AZLINT_VERSION}-shellcheck"
fi

docker push "matejkosiarcik/azlint:${AZLINT_VERSION}"
docker push "matejkosiarcik/azlint:internal-${AZLINT_VERSION}-alpine"
docker push "matejkosiarcik/azlint:internal-${AZLINT_VERSION}-debian"
docker push "matejkosiarcik/azlint:internal-${AZLINT_VERSION}-python"
docker push "matejkosiarcik/azlint:internal-${AZLINT_VERSION}-node"
docker push "matejkosiarcik/azlint:internal-${AZLINT_VERSION}-composer"
docker push "matejkosiarcik/azlint:internal-${AZLINT_VERSION}-go"
docker push "matejkosiarcik/azlint:internal-${AZLINT_VERSION}-shellcheck"
