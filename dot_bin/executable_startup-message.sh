#######################################################
#                      Credits                        #
#                    Made by Meow                     #
#                                                     #
#      Cat: https://www.asciiart.eu/animals/cats      #
#                                                     #
#######################################################

# Run With
# bash <(curl -sS "https://raw.githubusercontent.com/itzTheMeow/itzTheMeow/main/prompt.sh?$(date +%s)")

# Works On
# DEBIAN/UBUNTU BASED DISTROS ONLY
# YOU CAN ADAPT IT YOURSELF TO USE YOUR OWN DISTRO

if ! command -v lolcat &> /dev/null
then
    echo "Couldn't find lolcat, installing..."
    sudo apt-get install -y lolcat > /dev/null
fi

if ! command -v mpstat &> /dev/null
then
    echo "Couldn't find sysstat, installing..."
    sudo apt-get install -y sysstat > /dev/null
fi

REL="$(lsb_release -d)"
UP="$(uptime -p)"

echo -e "
  \    /\   $(whoami)@$(hostname) on ${REL:13}
   )  ( ')  CPU: $(mpstat | awk 'END{print 100-$NF"%"}')
  (  /  )   MEM: $(awk '/^Mem/ {print $3}' <(free -m))mb/$(awk '/^Mem/ {print $2}' <(free -m))mb
   \(__)|   DSK: $(awk '/^\/dev/ {print $3}' <(df -H | grep " /$"))B/$(awk '/^\/dev/ {print $2}' <(df -H | grep " /$"))B

  Uptime: ${UP:3}
  Packages: $(dpkg --list | wc --lines)
" | lolcat
