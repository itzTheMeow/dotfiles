#######################################################
#                                                     #
#                      Credits                        #
#                    Made by Meow                     #
#                                                     #
#      Cat: https://www.asciiart.eu/animals/cats      #
#                                                     #
#######################################################

# If you want to use this in your own setup, and don't want to copy the files, you can use this one-liner.
# bash <(curl -sS "https://raw.githubusercontent.com/itzTheMeow/dotfiles/refs/heads/master/dot_bin/executable_startup-message.sh?$(date +%s)")

# This script is meant to work on at least debian/ubuntu based distros and MacOS (with homebrew).
# If you find any issues, submit an issue or PR.

if ! command -v lolcat &> /dev/null
then
    echo "Couldn't find lolcat, installing..."
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    sudo apt-get install -y lolcat > /dev/null
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    brew install lolcat
  fi
fi

format_bytes() {
  echo "$1" | awk '{
    units = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
    sum = $1;
    for (i = 0; sum >= 1024 && i < 8; i++) sum /= 1024;
    print sum " " units[i]
  }'
}

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    REL=$(lsb_release -d | cut -f2-)
    UP=$(uptime -p | cut -d " " -f2-)
    CPU_USAGE=$(mpstat | awk 'END{print 100-$NF"%"}')
    MEM_TOTAL=$(awk '/^MemTotal/ {print $2}' /proc/meminfo)
    MEM_FREE=$(awk '/^MemAvailable/ {print $2}' /proc/meminfo)
    MEM_USED=$(( (MEM_TOTAL - MEM_FREE) / 1024 ))
    MEM_TOTAL=$((MEM_TOTAL / 1024))
    MEM_PERC=$(( (MEM_USED * 100) / MEM_TOTAL ))
    DISK_USAGE=$(df -H / | awk 'NR==2 {print $3}')
    DISK_TOTAL=$(df -H / | awk 'NR==2 {print $2}')
    DISK_PERC=$(df -H / | awk 'NR==2 {print $5}')
    PKG_COUNT=$(dpkg --list 2>/dev/null | wc -l || rpm -qa | wc -l)
elif [[ "$OSTYPE" == "darwin"* ]]; then
    REL="$(sw_vers -productName) $(sw_vers -productVersion)"
    UP=$(uptime | awk -F'(up |,)' '{print $2}')
    CPU_USAGE=$(top -l 1 -n 0 -s 0 | grep -E "^CPU" | awk '{ print $3 + $5"%" }')
    MEM_TOTAL=$(sysctl -n hw.memsize)
    MEM_TOTAL=$((MEM_TOTAL / 1024 / 1024))
    MEM_USED=$(vm_stat | awk '/Pages active/ {print $3}' | sed 's/\.//' | awk '{print int($1 * 4096 / 1024 / 1024 + 0.5)}')
    MEM_PERC=$(( (MEM_USED * 100) / MEM_TOTAL ))
    LISTED_DISKS=$(diskutil list -plist /)
    DISK_USAGE=$(echo "$LISTED_DISKS" | awk '/<key>CapacityInUse<\/key>/ {getline; print $1}' | grep -o '[0-9]\+' | awk 'BEGIN {ORS="\n"} {sum += $1} END {print sum}')
    DISK_TOTAL=$(df -H / | awk 'NR==2 {print $2}')
    DISK_PERC=$(df -H / | awk 'NR==2 {print $5}')
    PKG_COUNT=$(brew list --formula | wc -l)
fi

# Calculates the length of each string for alignment of percentages.
MEM_TEXT="${MEM_USED}MB/${MEM_TOTAL}MB"
DISK_TEXT="$(format_bytes $DISK_USAGE)/${DISK_TOTAL}B"
TXT_LENGTH=$(( ${#MEM_TEXT} > ${#DISK_TEXT} ? ${#MEM_TEXT} : ${#DISK_TEXT} ))
MEM_SPACES=$(( TXT_LENGTH - ${#MEM_TEXT} + 1 ))
DISK_SPACES=$(( TXT_LENGTH - ${#DISK_TEXT} + 1 ))

echo "
  \    /\   $(whoami)@$(hostname) on ${REL}
   )  ( ')  CPU: ${CPU_USAGE}
  (  /  )   MEM: ${MEM_TEXT}$(printf '%*s' "$MEM_SPACES")(${MEM_PERC}%)
   \(__)|   DSK: ${DISK_TEXT}$(printf '%*s' "$DISK_SPACES")(${DISK_PERC})

  Uptime: ${UP}
  Packages: $(echo "${PKG_COUNT}" | awk '{printf "%'\''d\n", $1}')
" | lolcat
