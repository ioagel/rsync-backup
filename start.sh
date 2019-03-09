#!/usr/bin/env bash

CRON_SCHEDULE=${CRON_SCHEDULE:-'0 0 * * *'}

if [[ -z ${REMOTE_PATH} ]]; then
    echo "[ERROR] REMOTE_PATH env var is REQUIRED"
    echo "Exiting Container ..."
    exit 255
fi

if [[ -z ${REMOTE_HOST} ]]; then
    echo "[ERROR] REMOTE_HOST env var is REQUIRED"
    echo "Exiting Container ..."
    exit 255
fi


# thanks to mysql official image for the following func
# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
file_env() {
    local var="$1"
    local fileVar="${var}_FILE"
    local def="${2:-}"
    if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
        echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
        exit 1
    fi
    local val="$def"
    if [ "${!var:-}" ]; then
        val="${!var}"
    elif [ "${!fileVar:-}" ]; then
        val="$(< "${!fileVar}")"
    fi
    export "$var"="$val"
    unset "$fileVar"
}

if [[ -n ${MAILTO} ]]; then
    file_env 'SMTP_PASSWD'
    if [[ -z "${SMTP_HOST}" || -z "${SMTP_PORT}" || -z "${MAILFROM}" || -z "${SMTP_USER}" || -z "${SMTP_PASSWD}" ]]; then
        echo "[ERROR] Mail cannot be sent: SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASSWD, MAILFROM env vars are required!"
        echo "Exiting Container ..."
        exit 255
    fi
    touch /var/log/msmtp.log
    cat <<EOF >/etc/msmtprc
defaults
auth           on
tls            on
tls_starttls   on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        /var/log/msmtp.log

account  backup
host     ${SMTP_HOST}
port     ${SMTP_PORT}
from     ${MAILFROM}
user     ${SMTP_USER}
password ${SMTP_PASSWD}
EOF
fi

echo "${CRON_SCHEDULE} /bin/bash /rsync_backup.sh" > /crontab
crontab /crontab

exec crond -f
