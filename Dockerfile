FROM alpine:3.12

LABEL author="Ioannis Angelakopoulos <ioagel@gmail.com>"

RUN apk add --no-cache rsync openssh-client msmtp ca-certificates bash && \
  mkdir /backup

RUN update-ca-certificates

COPY rsync_backup.sh start.sh /

VOLUME ["/backup"]

CMD ["/bin/bash", "/start.sh"]
