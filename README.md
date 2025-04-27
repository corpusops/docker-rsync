# docker rsync+bash static image
Mainly to be used in ci/cd pipelines to replace docker --squash steps.

build: https://hub.docker.com/r/corpusops/rsync

utilies bundled:
- bash
- busybox
- rsync (staticly built, and without SSH capabilities), for a full fledged rsync+ssh, use [`corpusops/sshd`](https://github.com/corpusops/docker-sshd) image.
