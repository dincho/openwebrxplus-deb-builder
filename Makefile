##  
# OpenWebRX+ DEB packages builder
#  

.DEFAULT_GOAL := help

HAS_PODMAN := $(shell podman -v 2>/dev/null || false)
HAS_BUILDAH := $(shell buildah -v 2>/dev/null || false)
HAS_DOCKER := $(shell docker -v 2>/dev/null || false)
HAS_BUILDX := $(shell docker buildx version 2>/dev/null || false)

.ONESHELL:

## Targets:
.PHONY: help
## Print this help
help: checks helpmakefile

# example env file
define example_env
# Set the required variables
REGISTRY="docker.com"
REGISTRYUSER="slechev"
IMAGE_NAME="openwebrxplus-deb-builder"

# should be a bash array in ()
ARCHITECTURES=(amd64 arm64 armhf)

# my fork
#BUILDSCRIPT=https://raw.githubusercontent.com/0xAF/openwebrxplus/master/buildall.sh
# official OWRX+ build script
BUILDSCRIPT=https://raw.githubusercontent.com/luarvique/openwebrx/master/buildall.sh

# pass arguments to build script
#BUILDSCRIPT_ARGS="--ask"
endef
export example_env

# load and export all env vars
ifneq (,$(wildcard ./settings.env)) # check if file exists
    include settings.env
    export
endif


.PHONY: checks
# check for the tools
checks:
	@
	$(info OpenWebRX+ DEB packages builder make script)
	$(info )
# do we have podman/buildah
ifdef HAS_PODMAN
ifndef HAS_BUILDAH
	$(info Podman detected, but Buildah is missing. Cannot use Podman.)
else
	$(eval CAN_PODMAN = $(HAS_PODMAN), $(HAS_BUILDAH))
	$(info Podman: $(CAN_PODMAN))
endif
else
	$(info Podman: not installed.)
endif
# do we have docker/buildx
ifdef HAS_DOCKER
ifndef HAS_BUILDX
	$(info Docker detected, but BuildX is missing. Cannot use Docker.)
else
	$(eval CAN_DOCKER = $(HAS_DOCKER), $(HAS_BUILDX))
	$(info Docker: $(CAN_DOCKER))
endif
else
	$(info Docker: not installed.)
endif
# report what we have
	$(if $(CAN_PODMAN), \
		$(info Preferred builder Podman/Buildah.), \
		$(if $(CAN_DOCKER), \
			$(info Preferred builder Docker/BuildX), \
			$(error Neither Podman nor Docker is installed. Cannot continue.) \
		) \
	)
# check for settings.env
ifeq (,$(wildcard ./settings.env)) # check if file exists
	$(error settings.env file does not exist. Use 'make settings' to create and edit.)
endif
	echo Image: $(REGISTRY)/$(REGISTRYUSER)/$(IMAGE_NAME)
	echo Architectures\(bash array\): $${ARCHITECTURES}
	echo


.PHONY: helpmakefile
# print help by parsing the makefile
helpmakefile:
	@awk '/^## / \
		{ if (c) {printf "\033[1m%s\033[0m\n", c}; c=substr($$0, 4); next } \
		c && /(^[[:alpha:]][[:alnum:]_-]+:)/ \
		{printf "\033[36m%-30s\033[0m \033[1m%s\033[0m\n", $$1, c; c=0} \
		END { printf "\033[1m%s\033[0m\n", c }' $(MAKEFILE_LIST)


.PHONY: settings
## edit settings with $EDITOR or vim
settings:
	@if [ ! -f ./settings.env ]; then echo "$$example_env" > settings.env; fi
	@$${EDITOR:-vim} ./settings.env

define create_podman_builders
	@
	. ./settings.env
	echo [+] Creating builders with Podman/Buildah

	echo [+] Removing old manifest, if any...
	buildah manifest rm $${IMAGE_NAME} || true
	echo [+] Creating new manifest...
	buildah manifest create $${IMAGE_NAME}

	@for file in Dockerfile*; do
		IMAGE_TAG=$$(echo $$file | sed -e 's/^Dockerfile-//' )
		echo -e [++] Creating builders for "\e[36m$${IMAGE_TAG}\e[0m"

		for arch in "$${ARCHITECTURES[@]}"; do
			echo -e [+++] "\e[36m$$IMAGE_TAG\e[0m": create builder for "\e[36m$$arch\e[0m"
			time buildah bud \
			--tag "$${REGISTRY}/$${REGISTRYUSER}/$${IMAGE_NAME}:$${IMAGE_TAG}-$${arch}" \
			--manifest $${IMAGE_NAME} \
			--arch $${arch} \
			-f $$file \
			.
		done

		echo [++] $$IMAGE_TAG: push all arch to manifest
		buildah manifest push --all \
			$${IMAGE_NAME} \
			"docker://$${REGISTRY}/$${REGISTRYUSER}/$${IMAGE_NAME}:$${IMAGE_TAG}"
		done
endef

define create_docker_builders
	@
	echo Creating builders with Docker/BuildX
endef


.PHONY: create
## Create builder images with preferred tool
create: checks
	$(if $(CAN_PODMAN), \
		$(call create_podman_builders), \
		$(if $(CAN_DOCKER), \
			$(call create_docker_builders), \
		) \
	)


## Create builder images with Podman
create_podman: checks
	$(if $(CAN_PODMAN), \
		$(call create_podman_builders), \
		$(error Cannot use Podman.) \
	)

## Create builder images with Docker
create_docker: checks
	$(if $(CAN_DOCKER), \
		$(call create_docker_builders), \
		$(error Cannot use Docker.) \
	)


#=====================================================================

define build_podman
	@
	. ./settings.env
	echo [+] Building packages with Podman/Buildah
	for image in $$(podman image ls -a -n | grep $${IMAGE_NAME} | grep -v latest | awk '{print $$2}'); do
		distro=$$(echo $$image | cut -d '-' -f 1)
		release=$$(echo $$image | cut -d '-' -f 2)
		arch=$$(echo $$image | cut -d '-' -f 3)
		echo =====================
		echo -e running "\e[36m$$arch\e[0m" build for "\e[36m$$distro $$release\e[0m"
		echo
		mkdir -p owrx/$$distro/$$release/$$arch
		time podman run -it --rm --arch $$arch \
			-v ./owrx/$$distro/$$release/$$arch:/owrx --name owrx-build-$$image \
			-e BUILDSCRIPT="$${BUILDSCRIPT}" \
			-e BUILDSCRIPT_ARGS="$${BUILDSCRIPT_ARGS}" \
			docker://$${REGISTRY}/$${REGISTRYUSER}/$${IMAGE_NAME}:$$image
	done
endef

define build_docker
	@
	. ./settings.env
	echo [+] Building packages with Docker/BuildX
endef


.PHONY: build
## Build DEB packages with preferred tool
build: checks
	$(if $(CAN_PODMAN), \
		$(call build_podman), \
		$(if $(CAN_DOCKER), \
			$(call build_docker), \
		) \
	)

## Build DEB packages with Podman
build_podman: checks
	$(if $(CAN_PODMAN), \
		$(call build_podman), \
		$(error Cannot use Podman.) \
	)

## Build DEB packages with Docker
build_docker: checks
	$(if $(CAN_DOCKER), \
		$(call build_docker), \
		$(error Cannot use Docker.) \
	)





##  
## Choose a target to run
##  
