#!/usr/bin/env bash

function show_usage {
	echo "
This script backups (full clone) virtualbox virtual machines. VMs are \
shutdown, export and reboot. Two backups are kept and the oldest is deleted \
at each run. For an automatically execution, use this script in a crontab. \
Below an example for a weekly backup:

cron ...

usage: virtualbox_backups.sh [options] vm1 \"my vm2\" [...]

    -h                help, print usage 
    -v 0|1|2|3        log level 0=off, 1=error, 2=info, 3=debug
    -d [path_to_dir]  path to directory where to store backups, clones
    -l 
	"
}

function log {
	case "$1" in
		error)
			level=1
			;;
		info)	
			level=2
			;;
		debug)
			level=3
			;;
	esac

	if [ $level -le $log_level ]
	then
		echo "###" "level: ${1}" "---" `date` "###"
		echo "###" "message: ${2}" "###"
	fi
}

backup_dir=""
vm_list=""

## set options
while getopts "hd:v:" opt
do
	case "$opt" in
		h|\?)
			show_usage
			exit 0
			;;
		v)
			log_level=$OPTARG
			;;
		d)
			backup_dir=$OPTARG
			;;
	esac
done
shift $((OPTIND-1))

## check options
if [ -z $log_level ]
then
	log_level=0
fi

if [ -z $backup_dir ]
then
	echo "missing backup directory, set this option with -d"
	exit 0
fi

if [ ! -d $backup_dir ]
then
	echo "specified backup directory does not exist: ${backup_dir}"
	exit 0
fi

if [ "$1" == "" ]
then
	echo "error, no vm to backup, please see script usage with -h option"
	exit 0
fi


log "info" "virtualbox backup started"

## set vm list and check if exists
declare -a vm_list
index=0
for vm in "$@"
do
	vm_list[$index]=$vm
	index=$((index + 1))
done

log "debug" "list of vms to save: ${vm_list[*]}"

## check vm appliances
declare -a known_vm_list
index=0
tmpfile=$(mktemp)
VBoxManage list vms > ${tmpfile}

while read line
do
	known_vm_list[$index]=`echo $line | awk -F'"' '{print $2}'`
	index=$((index + 1))
done <${tmpfile}


for vm in "${vm_list[@]}"
do
	flag_status="nok"
	for known_vm in "${known_vm_list[@]}"
	do
		if [ "${vm}" == "${known_vm}" ]
		then 
			flag_status="ok"
			break
		fi
	done
	if [ ${flag_status} != 'ok' ]
	then
		log "error" "unknown vm: ${vm}"
		exit 1
	fi
done

for vm in "${vm_list[@]}"
do
	# test vm status
	vm_status=`VBoxManage showvminfo --machinereadable "$vm" | grep VMState= | awk -F'"' '{print $2}'`
	log "info" "vm ${vm} status: ${vm_status}"

	# stop the vm if necessary
	if [ $vm_status == 'running' ]
	then
		log "info" "vm ${vm} is shutting down"
		VBoxManage controlvm "${vm}" acpipowerbutton
		while [ ${vm_status} != 'poweroff' ]
		do
			log "info" "waiting for ${vm} shutdown"
			sleep 5 
			vm_status=`VBoxManage showvminfo --machinereadable "$vm" | grep VMState= | awk -F'"' '{print $2}'`
		done

	elif [ $vm_status == 'poweroff' ]
	then
		log "info" "vm ${vm} has already been shutdown"
	else
		log "error" "vm ${vm} status unknown or untractable"
		exit 1
	fi
	# export the vm
	timestamp=`date "+%F"`
	vm_backup=$backup_dir/${vm}-$timestamp.ova
	log "info" "exporting ${vm} to ${vm_backup}"
	VBoxManage export "${vm}" -o "${vm_backup}"

	# reboot the vm
	log "info" "${vm} is starting"
	VBoxManage startvm "${vm}" --type headless

	# delete the oldest clone
	tmpfile=$(mktemp)
	ls -tr "${backup_dir}/${vm}"*>${tmpfile}
	## check the availability of 3 clones (the old to remove, 
	## the new just created, the intermediate to keep)
	nb_clones=`wc -l ${tmpfile} | cut -f1 -d" "`
	if [ "${nb_clones}" -lt 3 ]
	then
		log "error" "backups deletion error for ${vm}, missing previous clones"
		exit 1
	else
		old_vm=`head -n 1 ${tmpfile}`
		log "info" "removing old clone: ${old_vm}"
		rm "${old_vm}"
	fi
done

log "info" "virtualbox backup finished"
