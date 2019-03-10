#!/usr/bin/env bash

# Author:   Ioannis Angelakopoulos <ioagel@gmail.com>
# Date:     07/02/2019

#########################################################
# Modify below variables to fit your need ----
#########################################################
[[ -f "/backup-env" ]] && source /backup-env

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
    # ${REMOTE_PATH%/} -> removes 'slash' from ending of path, if it exists
    LOGFILE_MAIN="${BACKUP_LOG_DIR}/$(basename ${REMOTE_PATH%/})_${REMOTE_HOST}.log"
    LOGFILE_TEMP="/tmp/$(basename ${REMOTE_PATH%/})_${REMOTE_HOST}_${TIMESTAMP}.log"

    # Check and create directories.
    [[ ! -d "${BACKUP_DIR}" ]] && mkdir -p "${BACKUP_DIR}" 2>/dev/null
    [[ ! -d "${BACKUP_LOG_DIR}" ]] && mkdir -p "${BACKUP_LOG_DIR}" 2>/dev/null

    # Initialize temp log file.
    echo "==========================================================" > "${LOGFILE_TEMP}"
    echo "* Starting backup: ${TIMESTAMP}" >> "${LOGFILE_TEMP}"
    echo "* Backup directory: ${BACKUP_DIR}" >> "${LOGFILE_TEMP}"


    # Backup.
    echo "* Backing up remote target: ${REMOTE_PATH} of host: ${REMOTE_HOST}" >> "${LOGFILE_TEMP}"
    sed -n 1,4p "${LOGFILE_TEMP}"
    ${CMD_RSYNC} \
        ${RSYNC_OPTIONS} \
        -e "ssh -o StrictHostKeyChecking=no -i ${RSYNC_SSH_KEY}" \
        "${USER}"@"${REMOTE_HOST}":"${REMOTE_PATH}" \
        "${BACKUP_DIR}" 2>&1 | grep -v "${SUPPRESS_SSH_WARNING}" >> "${LOGFILE_TEMP}"

    if [[ "${PIPESTATUS[0]}" == '0' ]]; then
            echo "  - [DONE]" >> "${LOGFILE_TEMP}"
    else
        BACKUP_SUCCESS='NO'
    fi

    echo "* Backup completed (Success? ${BACKUP_SUCCESS})." >> "${LOGFILE_TEMP}"
}

send_mail() {
    cp ${LOGFILE_TEMP} /tmp/mail_file
    MAIL_FILE=/tmp/mail_file
    sed -i '1d;$d' ${MAIL_FILE}
    sed -i "1s/^/To: ${MAILTO}\n/" ${MAIL_FILE}
    # I needed to change the '/' delimiter to '@' because $REMOTE_PATH can contain slashes!!!
    sed -i "2s@^@Subject: RSYNC BACKUP - TARGET: ${REMOTE_PATH} - HOST: ${REMOTE_HOST}\n@" ${MAIL_FILE}
    sed -i "3s/^/*** Backup completed (Success? ${BACKUP_SUCCESS})\n/" ${MAIL_FILE}
    sed -i "4s/^/***\n/" ${MAIL_FILE}
    sed -i "5s/^/-----------DETAILED REPORT-----------\n/" ${MAIL_FILE}

    cat ${MAIL_FILE} | ${CMD_MAIL} -C /etc/msmtprc -a backup "${MAILTO}"
    if [[ "${PIPESTATUS[1]}" == '0' ]]; then
        echo "* E-mail Sent!" >> "${LOGFILE_TEMP}"
    else
        echo "[ERROR] E-mail Failed, please see logs: /var/log/msmtp.log" >> "${LOGFILE_TEMP}"
    fi
    # remove temp mail file, we do not need it anymore.
    rm -f ${MAIL_FILE}
}

backup
if [[ -n ${MAILTO} ]]; then
    send_mail
fi
sed -n '5,$p' "${LOGFILE_TEMP}"
# Append temp log to main logfile and remove temp log.
cat ${LOGFILE_TEMP} >> ${LOGFILE_MAIN}
rm -f ${LOGFILE_TEMP}

exit 0
