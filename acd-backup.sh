# /bin/bash
# Backup script to Amazon Cloud Drive
# Requires acd_cli to be initialized 

set -u
VERSION="1.0"

# CONFIG #

# Set your backup locations here (folders)
backup_locations=('/var/www' '/etc')

# END CONFIG #

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

function msg {
  echo -e "\e[38;5;3m# \e[38;5;80m$1 \e[38;5;3m> \e[38;5;82m$2\e[0m"
}

function msgred {
  echo -e "\e[38;5;3m#$RED $1 \e[38;5;3m> \e[38;5;82m$2\e[0m"
}

function pkgcheck {
  if [ $(dpkg-query -W -f='${Status}' $1 2>/dev/null | grep -c "ok installed") -eq 0 ];
  then
    msg "PKGCHECK" "Installing $1"
    apt-get install -y $1;
  fi
}

function redtext {
  echo -e "${RED}$1${NC}"
}
function greentext {
  echo -e "${GREEN}$1${NC}"
}

#Start script
if [[ $EUID -ne 0 ]]; then
   msgred "WARN" "You are not running this script as root; make sure you have access to all directories"
fi

msg "INFO" "Checking we have needed packages installed"
pkgcheck zip
pkgcheck tar
pkgcheck ncurses-term
echo ""
echo -e "${RED}YodaBackup $VERSION${NC} - $(date)"
echo ""
msg "INFO" "Script starting"
echo ""

HOST=$(hostname)
TMPDIR="/tmp/acdbackup"
rm -r $TMPDIR
mkdir -p $TMPDIR
DATE=$(date +"%Y.%m.%d-%H:%M:%S")

echo "[$DATE] [BACKUP] [INFO] Starting backup"
msg "ACD" "Making needed ACD files and folders..."
/usr/local/bin/acdcli create backup
/usr/local/bin/acdcli create backup/$HOST
/usr/local/bin/acdcli create backup/$HOST/$DATE
msg "BACKUP" "Starting backups..."
msgred "WARN" "Please do not interrupt"
echo ""

for loc in "${backup_locations[@]}"
do
  msg "BACKUP" "Starting backup $loc"
  echo "$loc" > .yodabackup_tmp
  sed -i 's/\//./g' .yodabackup_tmp
  FILENAME=$(cat .yodabackup_tmp)

  rm .yodabackup_tmp
  ZIPNAME="$HOST-$DATE-$FILENAME.zip"
  ZIPLOC="/tmp/yodabackup/$ZIPNAME"
  zip -r "$ZIPLOC" "$loc"
  msg "BACKUP" "Zipped $loc"
  msg "BACKUP" "Uploading $ZIPNAME"
  /usr/local/bin/acdcli upload -x 50 $ZIPLOC backup/$HOST/$DATE
  msg "BACKUP" "Uploaded $ZIPNAME to ACD: backup/$HOST/$DATE/$ZIPNAME"
done
echo ""
msg "INFO" "Script finished, enjoy"
/usr/local/bin/acdcli ls backup/$HOST/$DATE
FINISH_DATE=$(date +"%Y.%m.%d-%H:%M:%S")

echo "[$FINISH_DATE] [BACKUP] [INFO] Finished backup\n $(/usr/local/bin/acdcli ls backup/$HOST/$DATE)"

msg "CLEANUP" "Cleaning up temporary directories"
rm -r $TMPDIR