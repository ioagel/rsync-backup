FROM alpine:3.9

MAINTAINER Ioannis Angelakopoulos<ioagel@gmail.com>

RUN apk add --no-cache rsync openssh-client && \
  mkdir /backup

VOLUME ["/backup"]
