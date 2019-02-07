#!/usr/bin/env bash

# Author:   Ioannis Angelakopoulos <ioagel@gmail.com>
# Date:     07/02/2019

#########################################################
# Modify below variables to fit your need ----
#########################################################
# Where to store backup copies.
BACKUP_ROOTDIR=${BACKUP_ROOTDIR:-/backup} # for docker, mount a volume here

# REQUIRED
REMOTE_HOST=${REMOTE_HOST}
REMOTE_PATH=${REMOTE_PATH}

RSYNC_OPTIONS=${RSYNC_OPTIONS:--a --delete}
RSYNC_SSH_KEY=${RSYNC_SSH_KEY:-/run/secrets/rsync_ssh_key}
USER=${USER:-root}

# MAIL Settings
MAILTO=${MAILTO}

#########################################################
# You do *NOT* need to modify below lines.
#########################################################
PATH='/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/local/sbin'

# Commands.
CMD_RSYNC='rsync'
CMD_MAIL='msmtp'
CMD_DATE='/bin/date'

BACKUP_SUCCESS='YES'
SUPPRESS_SSH_WARNING="Permanently added"

backup() {
    # Date.
    YEAR="$(${CMD_DATE} +%Y)"
    MONTH="$(${CMD_DATE} +%m)"
    DAY="$(${CMD_DATE} +%d)"
    TIME="$(${CMD_DATE} +%H.%M.%S)"
    TIMESTAMP="${YEAR}.${MONTH}.${DAY}.${TIME}"

    BACKUP_DIR="${BACKUP_ROOTDIR}/${REMOTE_HOST}/"
    BACKUP_LOG_DIR="${BACKUP_ROOTDIR}/logs"

    # Log file
    LOGFILE="${BACKUP_LOG_DIR}/${TIMESTAMP}.log"

    # Check and create directories.
    [[ ! -d "${BACKUP_DIR}" ]] && mkdir -p "${BACKUP_DIR}" 2>/dev/null
    [[ ! -d "${BACKUP_LOG_DIR}" ]] && mkdir -p "${BACKUP_LOG_DIR}" 2>/dev/null

    # Initialize log file.
    echo "==========================================================" > "${LOGFILE}"
    echo "* Starting backup: ${TIMESTAMP}" >> "${LOGFILE}"
    echo "* Backup directory: ${BACKUP_DIR}" >> "${LOGFILE}"


    # Backup.
    echo "* Backing up remote target: ${REMOTE_PATH} of host: ${REMOTE_HOST}" >> "${LOGFILE}"
    sed -n 1,4p "${LOGFILE}"
    ${CMD_RSYNC} \
        ${RSYNC_OPTIONS} \
        -e "ssh -o StrictHostKeyChecking=no -i ${RSYNC_SSH_KEY}" \
        "${USER}"@"${REMOTE_HOST}":"${REMOTE_PATH}" \
        "${BACKUP_DIR}" 2>&1 | grep -v "${SUPPRESS_SSH_WARNING}" >> "${LOGFILE}"

    if [[ "${PIPESTATUS[0]}" == '0' ]]; then
            echo "  - [DONE]" >> "${LOGFILE}"
    else
        BACKUP_SUCCESS='NO'
    fi

    echo "* Backup completed (Success? ${BACKUP_SUCCESS})." >> "${LOGFILE}"
}

send_mail() {
    cp ${LOGFILE} /tmp/mail_file
    MAIL_FILE=/tmp/mail_file
    sed -i '1d;$d' ${MAIL_FILE}
    sed -i "1s/^/To: ${MAILTO}\n/" ${MAIL_FILE}
    # I needed to change the '/' delimiter to '@' because $REMOTE_PATH contains slashes!!!
    sed -i "2s@^@Subject: RSYNC BACKUP - TARGET: ${REMOTE_PATH} - HOST: ${REMOTE_HOST}\n@" ${MAIL_FILE}
    sed -i "3s/^/*** Backup completed (Success? ${BACKUP_SUCCESS})\n/" ${MAIL_FILE}
    sed -i "4s/^/***\n/" ${MAIL_FILE}
    sed -i "5s/^/-----------DETAILED REPORT-----------\n/" ${MAIL_FILE}

    cat ${MAIL_FILE} | ${CMD_MAIL} -C /etc/msmtprc -a backup "${MAILTO}"
    if [[ "${PIPESTATUS[1]}" == '0' ]]; then
        echo "* E-mail Sent!" >> "${LOGFILE}"
    else
        echo "[ERROR] E-mail Failed, please see logs: /var/log/msmtp.log" >> "${LOGFILE}"
    fi
    rm -f ${MAIL_FILE}
}

backup
if [[ -n ${MAILTO} ]]; then
    send_mail
fi
sed -n '5,$p' "$LOGFILE"

exit 0
