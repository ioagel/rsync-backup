# HOWTO

Rsync backup through ssh using CRON and optional e-mail functionality!

## Environment Variables

Override them according to your requirements.

```
    REMOTE_HOST             # REQUIRED
    REMOTE_PATH             # REQUIRED
    RSYNC_OPTIONS           # default = '-a --delete'
    RSYNC_SSH_KEY           # default = /run/secrets/rsync_ssh_key [for best practice and increased security, use swarm secrets to mount the key]
    USER                    # default = root
    CRON_SCHEDULE           # default = '0 0 * * *' [every day at 12am]
    MAILTO                  # REQUIRED for mail functionality [do not include it and no e-mail is sent]
    # The ENV vars below are required if MAILTO is set!
    MAILFROM                # REQUIRED [eg. username@gmail.com]
    SMTP_HOST               # REQUIRED [eg. smtp.gmail.com]
    SMTP_PORT               # REQUIRED [eg. 587]
    SMTP_USER               # REQUIRED [eg. username@gmail.com]
    SMTP_PASSWD[_FILE]      # REQUIRED [plain-text password or better, using _FILE and swarm secrets]
```

### TIP

Use **SWARM** mode even with one *HOST*, the overhead is very low and you get all the *magic* swarm provides, like *secret*, *config*, etc!
