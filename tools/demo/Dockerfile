FROM ubuntu:24.04@sha256:008173c23f95b170204355c12626cb5a965d779a7e1283b09e9cffbb1bf33ca3
ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8 TERM=xterm-256color
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl sudo \
    && useradd --create-home --shell /bin/bash demo \
    && printf 'demo ALL=(ALL) NOPASSWD: ALL\n' > /etc/sudoers.d/demo \
    && chmod 440 /etc/sudoers.d/demo
USER demo
WORKDIR /home/demo
CMD ["sleep", "infinity"]
