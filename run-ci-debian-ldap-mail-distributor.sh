#!/bin/bash

### LICENSE - (BSD 2-Clause) // ###
#
# Copyright (c) 2018, Daniel Plominski (ASS-Einrichtungssysteme GmbH)
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
# list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice, this
# list of conditions and the following disclaimer in the documentation and/or
# other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
# ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
### // LICENSE - (BSD 2-Clause) ###

### ### ### ASS // ### ### ###

LDAP_SRV_IP=$(grep LDAP_SRV_IP /custom_ldap_setting | sed 's/LDAP_SRV_IP=//g' | sed 's/"//g')
LDAP_SRV_PORT=$(grep LDAP_SRV_PORT /custom_ldap_setting | sed 's/LDAP_SRV_PORT=//g' | sed 's/"//g')
LDAP_SRV_USER=$(grep LDAP_SRV_USER /custom_ldap_setting | sed 's/LDAP_SRV_USER=//g' | sed 's/"//g')
LDAP_SRV_PW=$(grep LDAP_SRV_PW /custom_ldap_setting | sed 's/LDAP_SRV_PW=//g' | sed 's/"//g')

#// FUNCTION: spinner (Version 1.0)
spinner() {
   local pid=$1
   local delay=0.01
   local spinstr='|/-\'
   while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
         local temp=${spinstr#?}
         printf " [%c]  " "$spinstr"
         local spinstr=$temp${spinstr%"$temp"}
         sleep $delay
         printf "\b\b\b\b\b\b"
   done
   printf "    \b\b\b\b"
}

#// FUNCTION: run script as root (Version 1.0)
check_root_user() {
if [ "$(id -u)" != "0" ]; then
   echo "[ERROR] This script must be run as root" 1>&2
   exit 1
fi
}

#// FUNCTION: check state (Version 1.0)
check_hard() {
if [ $? -eq 0 ]
then
   echo "[$(printf "\033[1;32m  OK  \033[0m\n")] '"$@"'"
else
   echo "[$(printf "\033[1;31mFAILED\033[0m\n")] '"$@"'"
   sleep 1
   exit 1
fi
}

#// FUNCTION: check state without exit (Version 1.0)
check_soft() {
if [ $? -eq 0 ]
then
   echo "[$(printf "\033[1;32m  OK  \033[0m\n")] '"$@"'"
else
   echo "[$(printf "\033[1;33mWARNING\033[0m\n")] '"$@"'"
   sleep 1
fi
}

#// FUNCTION: check state hidden (Version 1.0)
check_hidden_hard() {
if [ $? -eq 0 ]
then
   return 0
else
   #/return 1
   checkhard "$@"
   return 1
fi
}

#// FUNCTION: check state hidden without exit (Version 1.0)
check_hidden_soft() {
if [ $? -eq 0 ]
then
   return 0
else
   #/return 1
   checksoft "$@"
   return 1
fi
}

#// FUNCTION: get active directory ldap mail distributor list
get_ldap_mail_list() {
   ldapsearch -H ldap://"$LDAP_SRV_IP":"$LDAP_SRV_PORT" -o ldif-wrap=no -x -D "CN=$LDAP_SRV_USER, OU=Benutzer, DC=ASSDOMAIN, DC=intern" -w "$LDAP_SRV_PW" -b "OU=Mail-Verteiler, OU=Benutzer, DC=ASSDOMAIN, DC=intern" -s sub 'objectClass=*' mail member | egrep -v "member:: " | sed '/^ /d' | sed '/^dn:/d' | awk -v RS= '{print > ("ldap-mail-list-" NR ".txt")}'
}

#// FUNCTION: get active directory ldap user list
get_ldap_user_list() {
   ldapsearch -H ldap://"$LDAP_SRV_IP":"$LDAP_SRV_PORT" -o ldif-wrap=no -x -D "CN=$LDAP_SRV_USER, OU=Benutzer, DC=ASSDOMAIN, DC=intern" -w "$LDAP_SRV_PW" -b "OU=Benutzer, DC=ASSDOMAIN, DC=intern" -s sub 'objectClass=user' mail | paste -d, -s | tr '#' '\n' | sed 's/^.*dn: /member: /' | sed 's/mail: /MAIL:/g' | grep "member:" | grep "MAIL:" | sed 's/,MAIL:/, mail:/g' > ldap-mail-users
}

#// FUNCTION: merge mail address
merge_mail_address() {
   for f in ldap-mail-list-*.txt
   do
      perl run_merge.pl $f ldap-mail-users | sort | sed 's/^.*mail:/mail:/' | grep "mail:" | sed 's/,,//g' | sed 's/ //g' | sed 's/mail://g' | tr '\n' ' ' > merge_$f
   done
}

#// FUNCTION: create virtual map
create_virtual_map() {
   rm -fv virtual_p1
   for file in merge_ldap-mail-list-*.txt
   do
      cat "$file" >> virtual_p1
      echo "" >> virtual_p1
   done
   sort virtual_p1 > virtual_p2
   sed '/^$/d' virtual_p2 > virtual_p3
   sed -e 'G;' virtual_p3 > virtual_p4
   #// short
   cat mail-verteiler_urlaub.txt > virtual_map_short
   cat mail-verteiler_mailbot.txt >> virtual_map_short
   cat mail-verteiler_custom.txt >> virtual_map_short
   echo "### ### ### // ASS - AUTOMATICALLY GENERATED ### ### ###" >> virtual_map_short
   echo "# EOF" >> virtual_map_short
   #// long
   cat mail-verteiler_custom.txt > virtual_map
   cat virtual_p4 >> virtual_map
   echo "### ### ### // ASS - AUTOMATICALLY GENERATED ### ### ###" >> virtual_map
   echo "# EOF" >> virtual_map
}

#// FUNCTION: check virtual map_short
check_virtual_map_short() {
   CHECK_VIRTUAL_MAP_SHORT=$(/usr/sbin/postmap virtual_map_short 2>&1 | wc -l)
   if [ "$CHECK_VIRTUAL_MAP_SHORT" = "0" ]
   then
      echo "[$(printf "\033[1;32m  OK  \033[0m\n")] check new virtual table (shortened version) passed."
   else
      echo "ERROR:"
      /usr/sbin/postmap virtual_map_short
      echo "[$(printf "\033[1;31mFAILED\033[0m\n")] check new virtual table (shortened version) goes wrong!"
      exit 1
   fi
}

#// FUNCTION: check virtual map
check_virtual_map() {
   CHECK_VIRTUAL_MAP=$(/usr/sbin/postmap virtual_map 2>&1 | wc -l)
   if [ "$CHECK_VIRTUAL_MAP" = "0" ]
   then
      echo "[$(printf "\033[1;32m  OK  \033[0m\n")] check new virtual table passed."
   else
      echo "ERROR:"
      /usr/sbin/postmap virtual_map
      echo "[$(printf "\033[1;31mFAILED\033[0m\n")] check new virtual table goes wrong!"
      exit 1
   fi
}

#// FUNCTION: transfer the virtual map
transfer_virtual_map() {
   sed -n '1p' /custom_dest_mailserver | while read VAR1 VAR2 VAR3
   do
      scp -i /id_ed25519_lx-confmailverteiler virtual_map "$VAR2"@"$VAR1":"$VAR3"
      if [ $? -eq 0 ]; then
         echo "[$(printf "\033[1;32m  OK  \033[0m\n")] transfer the virtual table to $VAR1 as $VAR3 passed."
      else
         echo "[$(printf "\033[1;31mFAILED\033[0m\n")] transfer the virtual table to $VAR1 as $VAR3 goes wrong!"
         return 1
      fi
   done
   if [ $? -eq 0 ]; then
      echo "[$(printf "\033[1;32m  OK  \033[0m\n")] transfer status passed."
   else
      echo "[$(printf "\033[1;31mFAILED\033[0m\n")] transfer status goes wrong!"
      exit 1
   fi
}

#// FUNCTION: transfer the virtual map
transfer_virtual_map_short() {
   sed -n '2p' /custom_dest_mailserver | while read VAR4 VAR5 VAR6
   do
      scp -i /id_ed25519_lx-confmailverteiler virtual_map_short "$VAR5"@"$VAR4":"$VAR6"
      if [ $? -eq 0 ]; then
         echo "[$(printf "\033[1;32m  OK  \033[0m\n")] transfer (shortened version) the virtual table to $VAR4 as $VAR6 passed."
      else
         echo "[$(printf "\033[1;31mFAILED\033[0m\n")] transfer (shortened version) the virtual table to $VAR4 as $VAR6 goes wrong!"
         return 1
      fi
   done
   if [ $? -eq 0 ]; then
      echo "[$(printf "\033[1;32m  OK  \033[0m\n")] transfer (shortened version) status passed."
   else
      echo "[$(printf "\033[1;31mFAILED\033[0m\n")] transfer (shortened version) status goes wrong!"
      exit 1
   fi
}

#// FUNCTION: create the remote virtual map
create_remote_virtual_map_srv1() {
   sed -n '1p' /custom_dest_mailserver | while read VAR7 VAR8 VAR9
   do
      ssh -i /id_ed25519_lx-confmailverteiler "$VAR8"@"$VAR7" /usr/sbin/postmap "$VAR9"
      if [ $? -eq 0 ]; then
         echo "[$(printf "\033[1;32m  OK  \033[0m\n")] create remote the virtual table to $VAR7 as $VAR9 passed."
      else
         echo "[$(printf "\033[1;31mFAILED\033[0m\n")] create remote the virtual table to $VAR7 as $VAR9 goes wrong!"
         return 1
      fi
   done
   if [ $? -eq 0 ]; then
      echo "[$(printf "\033[1;32m  OK  \033[0m\n")] remote virtual table status passed."
   else
      echo "[$(printf "\033[1;31mFAILED\033[0m\n")] remote virtual table status goes wrong!"
      exit 1
   fi
}

#// FUNCTION: create the remote virtual map
create_remote_virtual_map_srv2() {
   sed -n '2p' /custom_dest_mailserver | while read VAR10 VAR11 VAR12
   do
      ssh -i /id_ed25519_lx-confmailverteiler "$VAR11"@"$VAR10" /usr/sbin/postmap "$VAR12"
      if [ $? -eq 0 ]; then
         echo "[$(printf "\033[1;32m  OK  \033[0m\n")] create remote the virtual table to $VAR10 as $VAR12 passed."
      else
         echo "[$(printf "\033[1;31mFAILED\033[0m\n")] create remote the virtual table to $VAR10 as $VAR12 goes wrong!"
         return 1
      fi
   done
   if [ $? -eq 0 ]; then
      echo "[$(printf "\033[1;32m  OK  \033[0m\n")] remote virtual table status passed."
   else
      echo "[$(printf "\033[1;31mFAILED\033[0m\n")] remote virtual table status goes wrong!"
      exit 1
   fi
}

### RUN ###

get_ldap_mail_list
get_ldap_user_list

merge_mail_address
create_virtual_map

echo "### --- --- --- SHOW: virtual_map_shot --- --- --- ###"
cat -n virtual_map_short
check_virtual_map_short

echo "### --- --- --- SHOW: virtual_map --- --- --- ###"
cat -n virtual_map
check_virtual_map

transfer_virtual_map
transfer_virtual_map_short
create_remote_virtual_map_srv1
create_remote_virtual_map_srv2

### ### ### // ASS ### ### ###
exit 0
# EOF
