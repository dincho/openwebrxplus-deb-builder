# openwebrxplus-deb-builder
DEB packages builder for OpenWebRX+  
Build .deb packages for OWRX+ and it's dependencies using Docker/Podman.  
To build arm platforms, you need `qemu-user-static` package instaled.

NOTE: As of now the builder supports only Podman. Docker support will come later.

## podman
To use this builder with Podman, you might need to login to docker.io first:
```sh
podman login docker.io
```

## usage
To see the help:
```sh
make
```

## create/edit settings
You will need settings file in first place:
```sh
make settings
```

## create builder image for selected platforms in settings
To be able to build the DEBs, you need a builder. Let's create one.
```sh
make create
```

## building DEB packages for selected platforms
We are ready to build DEBs now.
```sh
make build
```
