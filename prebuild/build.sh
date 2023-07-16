#!/bin/sh
set -euf

cd "$(dirname "$0")"
currdir="$PWD"
cd "$(git rev-parse --show-toplevel)"

# cleanup previously built images
docker_image='matejkosiarcik/azlint-prebuild:dev'
docker rmi --force "$docker_image"

# cleanup old artifacts
outdir_global="$currdir/bin"
rm -rf "$outdir_global"

# Specify which platforms to build for
linux_platforms="amd64 arm64"
linux_platforms="$(printf '%s' "$linux_platforms" | tr ' ' '\n')"

printf '%s\n' "$linux_platforms" | while read -r platform; do
    platform="linux/$platform"
    docker build --tag "$docker_image" --platform "$platform" . --file "$currdir/Dockerfile"

    tmpdir="$(mktemp -d)"
    docker run --volume "$tmpdir:/output" --platform "$platform" "$docker_image" cp -R /app/bin /output

    outdir="$outdir_global/platform/$platform"
    mkdir -p "$outdir"
    cp -R "$tmpdir/bin/" "$outdir"

    archname="$(docker run --platform "$platform" "$docker_image" uname -m)"
    outdir="$outdir_global/arch/$archname"
    mkdir -p "$outdir"
    cp -R "$tmpdir/bin/" "$outdir"

    rm -rf "$tmpdir"
done
