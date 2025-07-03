#!/bin/bash

INPUT_PATH=$1
OUTPUT_DIR=$2
PKG_NAME=$3
PKG_VERSION=$4
GENERATOR=$5
shift 5
ADDITIONAL_PROPS=$@

USAGE="$0 input_path output_dir pkg_name pkg_version [generator [additional_props]]" 
echo Input: $INPUT_PATH
echo Output: $OUTPUT_DIR
echo Package name: $PKG_NAME
echo Package version: $PKG_VERSION
echo Generator: $GENERATOR

if [[ -z "${OUTPUT_DIR// }" ]]; then
	echo Invalid empty output dir
	echo USAGE: $USAGE
	exit -1
fi

if [[ $OUTPUT_DIR = '.' ]]; then
	echo Invalid output dir '.'
	echo USAGE: $USAGE
	exit -1
fi

if [[ -z $GENERATOR ]]; then
	GENERATOR=go
	ADDITIONAL_PROPS=--additional-properties=packageName=${PKG_NAME}
	ADDITIONAL_PROPS=${ADDITIONAL_PROPS},packageVersion=${PKG_VERSION}
	ADDITIONAL_PROPS=${ADDITIONAL_PROPS},enumClassPrefix=true
fi

echo Removing current api generated code
sudo rm -rf $OUTPUT_DIR

echo Launching docker container to generate the api code....
DOCKER_CMD="cylonix/openapi-generator-cli:v7.8.5 \
		generate -g ${GENERATOR} \
		-i /local/${INPUT_PATH} \
		-o /local/${OUTPUT_DIR} \
		--git-repo-id ${PKG_NAME}/v1 --git-user-id cylonix \
		--inline-schema-options RESOLVE_INLINE_ENUMS=true \
		${ADDITIONAL_PROPS}"

echo ${DOCKER_CMD}
docker run --rm -v "${PWD}:/local" ${DOCKER_CMD}

result=$?
if [[ $result != 0 ]]; then
	exit $result
fi

if grep -q "${OUTPUT_DIR}" .gitignore; then
	echo Generated files in ${OUTPUT_DIR} are already included in .gitignore
else
	echo Adding generated files in ${OUTPUT_DIR} to .gitignore
	echo "${OUTPUT_DIR}" >> .gitignore
fi

if [[ $GENERATOR = 'go' ]]; then
	cd "${OUTPUT_DIR}"; sudo chmod -R a+rw go.mod go.sum .; go mod tidy; go fmt
fi
