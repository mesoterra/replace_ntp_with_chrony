#!/bin/bash
timeserver_list=(0.rhel.pool.ntp.org 1.rhel.pool.ntp.org 2.rhel.pool.ntp.org 3.rhel.pool.ntp.org)

echo 'Removing NTP...'
# check if ntp is installed.
rpm -q ntp 2&>1 /dev/null
# set exit code to variable.
is_ntp_installed="$?"
# if is_ntp_installed equals 0, indicating that it is installed, then proceed.
if [[ ${is_ntp_installed} -eq '0' ]] ; then
    # stop ntpd
    systemctl stop ntp 2&>1 /dev/null
    # disable ntp
    systemctl disable ntp 2&>1 /dev/null
    # remove ntp
    yum -y remove ntp >> ${AUDITDIR}/service_remove_${TIME}.log
fi
# unset variable to prevent the possibility of future use.
unset is_ntp_installed

echo 'Installing Chrony...'
# installing chrony to handle server time.
# RHEL7 2.2.1.3 Ensure chrony is configured (Scored)
# check if chrony is installed.
rpm -q chrony 2&>1 /dev/null
# set exit code to variable.
is_chrony_installed="$?"
# if is_chrony_installed equals 1 which indicates that it is not installed, then proceed.
if [[ ${is_chrony_installed} -eq '1' ]] ; then
    # install chrony
    yum -y install chrony >> ${AUDITDIR}/service_add_${TIME}.log
fi
# re-check if chrony is installed.
rpm -q chrony 2&>1 /dev/null
# set exit code to variable.
is_chrony_installed="$?"
# if is_chrony_installed equals 0 then proceed, else echo error.
if [[ ${is_chrony_installed} -eq '0' ]] ; then
    # if there are lines that begin with server or pool then proceed.
    if [[ $(grep -P "^[[:blank:]]*(server|pool)[[:blank:]]+" /etc/chrony.conf) ]] ; then
        # comment out all lines that begin with server or pool that are not already comments.
        sed -i -e '/^[[:blank:]]*\(server\|pool\)[[:blank:]]\+.*$/ s/^#*/#/' /etc/chrony.conf
        # before the first instance of the newly commented server and pool lines add a new server line with the new time server.
        for each in ${timeserver_list[@]}
            do sed -i "0,/^[[:blank:]]*#[[:blank:]]*\(server\|pool\)[[:blank:]]\+.*$/s/^[[:blank:]]*#[[:blank:]]*\(server\|pool\)[[:blank:]]\+.*$/server ${each} iburst\n&/" /etc/chrony.conf
        done
    fi
    # check if there is an OPTIONS line in /etc/sysconfig/chronyd that doesn't contain the line we are about to add.
    if [[ -z $(grep -iP '^[[:blank:]]*OPTIONS[[:blank:]]*=[[:blank:]]*.*\-u[[:blank:]]+chrony.*$' /etc/sysconfig/chronyd) ]] ; then
        # if there is an OPTIONS line that contains a chrony flag that is not the one we want then proceed.
        if [[ $(grep -iP '^[[:blank:]]*OPTIONS[[:blank:]]*=[[:blank:]]*.*\-[a-tv-zA-TV-Z][[:blank:]]+chrony.*$' /etc/sysconfig/chronyd) ]] ; then
            # replace unwanted chrony flags.
            sed -i 's/\-[a-tv-zA-TV-Z] chrony/\-u chrony/g' /etc/sysconfig/chronyd
        # if there is an OPTIONS line that does not contain a chrony flag.
        elif [[ -z $(grep -iP '^[[:blank:]]*OPTIONS[[:blank:]]*=[[:blank:]]*.*\-[a-zA-Z][[:blank:]]+chrony.*$' /etc/sysconfig/chronyd) ]] ; then
            # if there is no content between the "" or '' in the OPTIONS line then proceed.
            if [[ $(grep -iP '^[[:blank:]]*OPTIONS[[:blank:]]*=[[:blank:]]*('\''|")[[:blank:]]*('\''|")[[:blank:]]*$' /etc/sysconfig/chronyd) ]] ; then
                # add our line without a preceeding space.
                sed -i 's/\('\''\|"\)$/\-u chrony&/' /etc/sysconfig/chronyd
            # if there is additional content between the '' or "" then proceed with this instead.
            elif [[ $(grep -iP '^[[:blank:]]*OPTIONS[[:blank:]]*=[[:blank:]]*('\''|")[[:blank:]]*.*[[:blank:]]*('\''|")[[:blank:]]*$' /etc/sysconfig/chronyd) ]] ; then
                # add line before last quote and prepend it with a space.
                sed -i 's/\('\''\|"\)$/ \-u chrony&/' /etc/sysconfig/chronyd
            fi
        fi
    else
        # if no OPTIONS line exists then add it.
        echo 'OPTIONS="-u chrony"' >> /etc/sysconfig/chronyd
    fi
else
    echo 'WARNING: Chrony is still not installed after it should have been installed by this script!!!'
fi
