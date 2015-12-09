#!/bin/sh
#Simple configuration tool inspired by raspi-config
INTERACTIVE=True
ASK_TO_REBOOT=0
BLACKLIST=/etc/modprobe.d/raspi-blacklist.conf
CONFIG=/boot/config.txt

#
# Basic Screen sizer
#
calc_wt_size() {
  # NOTE: it's tempting to redirect stderr to /dev/null, so supress error 
  # output from tput. However in this case, tput detects neither stdout or 
  # stderr is a tty and so only gives default 80, 24 values
  WT_HEIGHT=17
  WT_WIDTH=$(tput cols)

  if [ -z "$WT_WIDTH" ] || [ "$WT_WIDTH" -lt 60 ]; then
    WT_WIDTH=80
  fi
  if [ "$WT_WIDTH" -gt 178 ]; then
    WT_WIDTH=120
  fi
  WT_MENU_HEIGHT=$(($WT_HEIGHT-7))
}

#
# All do functions
#
# $1 is 0 to disable overscan, 1 to disable it
set_overscan() {
  # Stop if /boot is not a mountpoint
  if ! mountpoint -q /boot; then
    return 1
  fi

  [ -e $CONFIG ] || touch $CONFIG

  if [ "$1" -eq 0 ]; then # disable overscan
    sed $CONFIG -i -e "s/^overscan_/#overscan_/"
    set_config_var disable_overscan 1 $CONFIG
  else # enable overscan
    set_config_var disable_overscan 0 $CONFIG
  fi
}

do_overscan() {
  whiptail --yesno "What would you like to do with overscan" 20 60 2 \
    --yes-button Disable --no-button Enable
  RET=$?
  if [ $RET -eq 0 ] || [ $RET -eq 1 ]; then
    ASK_TO_REBOOT=1
    set_overscan $RET;
  else
    return 1
  fi
}

do_change_pass() {
  whiptail --msgbox "You will now be asked to enter a new password for the root user" 20 60 1
  passwd root &&
#need to add a variable to reset any password and list them
  whiptail --msgbox "Password changed successfully" 20 60 1
}

do_configure_keyboard() {
  dpkg-reconfigure keyboard-configuration &&
  printf "Reloading keymap. This may take a short while\n" &&
  invoke-rc.d keyboard-setup start
}

do_change_locale() {
  dpkg-reconfigure locales
}

do_change_timezone() {
  dpkg-reconfigure tzdata
}

do_change_hostname() {
  whiptail --msgbox "\
Please note: RFCs mandate that a hostname's labels \
may contain only the ASCII letters 'a' through 'z' (case-insensitive), 
the digits '0' through '9', and the hyphen.
Hostname labels cannot begin or end with a hyphen. 
No other symbols, punctuation characters, or blank spaces are permitted.\
" 20 70 1

  CURRENT_HOSTNAME=`cat /etc/hostname | tr -d " \t\n\r"`
  NEW_HOSTNAME=$(whiptail --inputbox "Please enter a hostname" 20 60 "$CURRENT_HOSTNAME" 3>&1 1>&2 2>&3)
  if [ $? -eq 0 ]; then
    echo $NEW_HOSTNAME > /etc/hostname
    sed -i "s/127.0.1.1.*$CURRENT_HOSTNAME/127.0.1.1\t$NEW_HOSTNAME/g" /etc/hosts
    ASK_TO_REBOOT=1
  fi
}

do_installsoft() {
  apt-get update &&
  apt-get install  &&
  printf "Sleeping 5 seconds before reloading raspi-config\n" &&
  sleep 5 &&
  exec ovh-tools
}

do_update() {
  apt-get update &&
  printf "Sleeping 5 seconds before reloading raspi-config\n" &&
  sleep 5 &&
  exec ovh-tools 
}

#
# Finish him
#
do_finish() {
  disable_raspi_config_at_boot
  if [ $ASK_TO_REBOOT -eq 1 ]; then
    whiptail --yesno "Would you like to reboot now?" 20 60 2
    if [ $? -eq 0 ]; then # yes
      sync
      reboot
    fi
  fi
  exit 0
}

#
# Internalisation Menu
#
do_internationalisation_menu() {
  FUN=$(whiptail --title "OVH Configuration Tool (ovh-config)" --menu "Internationalisation Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
    "I1 Change Locale" "Set up language and regional settings to match your location" \
    "I2 Change Timezone" "Set up timezone to match your location" \
    "I3 Change Keyboard Layout" "Set the keyboard layout to match your keyboard" \
    3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ]; then
    return 0
  elif [ $RET -eq 0 ]; then
    case "$FUN" in
      I1\ *) do_change_locale ;;
      I2\ *) do_change_timezone ;;
      I3\ *) do_configure_keyboard ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
  fi
}

#
# About Menu
#
do_about() {
  whiptail --msgbox "\
This tool provides a straight-forward way of doing initial
configuration of your server. Although it can be run
at any time, some of the options may have difficulties if
you have heavily customised your installation.\
" 20 70 1
}

#
# OVH Menu
#
do_ovh() {
  FUN=$(whiptail --title "OVH Configuration Tool (ovh-config)" --menu "OVH" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
    "O1 FtpBackup" "Mount an OVH FTP backup" \
    "O2 " "" \
    "O3 " "" \
    3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ]; then
    return 0
  elif [ $RET -eq 0 ]; then
    case "$FUN" in
      O1\ *) do_change_locale ;;
      O2\ *) do_change_timezone ;;
      O3\ *) do_configure_keyboard ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
  fi
}

#
# Soft install Menu
#
do_soft() {
  FUN=$(whiptail --title "OVH Configuration Tool (ovh-config)" --menu "Auto-install" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
    "S1 Minecraft" "Autoinstall Vanilla Minecraft" \
    "S2 Mumble" "Autoinstall Mumble" \
    "S3 Teamspeak" "Autoinstall Teamspeak" \
    "S4 E" "" \
    "S5 D" "" \
    "S6 S" "" \
    "S7 I" "" \
    "S8 S" "" \
    "S9 A" "" \
    "S0 Webmin" "Autoinstall Webmin" \
    3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ]; then
    return 0
  elif [ $RET -eq 0 ]; then
    case "$FUN" in
      S1\ *) do_minecraft ;;
      S2\ *) do_mumble ;;
      S3\ *) do_teamspeak ;;
      S4\ *) do_ ;;
      S5\ *) do_ ;;
      S6\ *) do_ ;;
      S7\ *) do_ ;;
      S8\ *) do_ ;;
      S9\ *) do_ ;;
      S0\ *) do_ ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
  fi
}

#
# Advanced options menu
#
do_advanced_menu() {
  FUN=$(whiptail --title "OVH Configuration Tool (ovh-config)" --menu "Advanced Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
    "A1 Overscan" "You may need to configure overscan if black bars are present on display" \
    "A2 Hostname" "Set the visible name for this server on a network" \
    "A3 Memory Split" "Change the amount of memory made available to the GPU" \
    "A4 SSH" "Enable/Disable remote command line access to your Pi using SSH" \
    "A5 Device Tree" "Enable/Disable the use of Device Tree" \
    "A6 SPI" "Enable/Disable automatic loading of SPI kernel module (needed for e.g. PiFace)" \
    "A7 I2C" "Enable/Disable automatic loading of I2C kernel module" \
    "A8 Serial" "Enable/Disable shell and kernel messages on the serial connection" \
    "A9 Audio" "Force audio out through HDMI or 3.5mm jack" \
    "A0 Update" "Update this tool to the latest version" \
    3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ]; then
    return 0
  elif [ $RET -eq 0 ]; then
    case "$FUN" in
      A1\ *) do_overscan ;;
      A2\ *) do_change_hostname ;;
      A3\ *) do_memory_split ;;
      A4\ *) do_ssh ;;
      A5\ *) do_devicetree ;;
      A6\ *) do_spi ;;      A7\ *) do_i2c ;;
      A8\ *) do_serial ;;
      A9\ *) do_audio ;;
      A0\ *) do_update ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
  fi
}

#
# Finish him
#
do_finish() {
  disable_raspi_config_at_boot
  if [ $ASK_TO_REBOOT -eq 1 ]; then
    whiptail --yesno "Would you like to reboot now?" 20 60 2
    if [ $? -eq 0 ]; then # yes
      sync
      reboot
    fi
  fi
  exit 0
}

#
# Loop menu
#
calc_wt_size
while true; do
  FUN=$(whiptail --title "OVH Configuration Tool (ovhtools)" --menu "Setup Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Finish --ok-button Select \
    "1 Set choice" "Set up language and regional settings to match your location" \
    "2 Change User Password" "Change password for the default user" \
    "3 Enable Boot to Desktop/Scratch" "Choose whether to boot into a desktop environment, Scratch, or the command-line" \
    "4 Internationalisation Options" "Set up language and regional settings to match your location" \
    "5 Configure Softs" "Configure and manage software" \
    "6 OVH Services" "Mount and configure OVH services" \
    "7 Auto-install Softs" "Auto installation of software" \
    "8 Advanced Options" "Configure advanced settings" \
    "9 About Ovhtools" "Information about this configuration tool" \
    "10 Remote manage" "Allows you to remotly install and manage your server using puppet" \
    3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ]; then
    do_finish
  elif [ $RET -eq 0 ]; then
    case "$FUN" in
      1\ *) do_ ;;
      2\ *) do_change_pass ;;
      3\ *) do_boot_behaviour ;;
      4\ *) do_internationalisation_menu ;;
      5\ *) do_softconf ;;
      6\ *) do_ovh ;;
      7\ *) do_soft ;;
      8\ *) do_advanced_menu ;;
      9\ *) do_about ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
  else
    exit 1
  fi
done
