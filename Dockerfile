FROM alpine:3.12

LABEL author="Ioannis Angelakopoulos <ioagel@gmail.com>"

RUN apk add --no-cache rsync tzdata openssh-client msmtp ca-certificates bash && \
  cp /usr/share/zoneinfo/Europe/Athens /etc/localtime && \
  echo "Europe/Athens" >  /etc/timezone && \
  mkdir /backup

RUN update-ca-certificates && apk del tzdata

COPY rsync_backup.sh start.sh /

VOLUME ["/backup"]

CMD ["/bin/bash", "/start.sh"]
