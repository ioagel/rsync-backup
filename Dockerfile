FROM debian:stretch-slim

MAINTAINER Ioannis Angelakopoulos<ioagel@gmail.com>

RUN apt-get update && apt-get install -y --no-install-recommends openssh-client rsync && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir /backup

VOLUME ["/backup"]
