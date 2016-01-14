#!/usr/bin/env bash

function show_usage {
	echo "
This script backups a mysql redmine instance (database dump and attached \
rsync).
For an automatically execution, use this script in a crontab. \
Below an example for a daily backup at 1:01 pm:

01 13	* * *	root	/root/redmine_backup.sh -d redmine_production \
-u root -p 'password' -f /var/www/redmine/files -r /backup_files -m /dumps \
-v 4 | mail -s "redmine backup" foo@bar.fr


usage: redmine_backup.sh [options]

    -h                help, print usage 
    -v 0|1|2|3        log level 0=off, 1=error, 2=info, 3=debug
    -d [database name]  database name (mandatory)
    -h [hostname]           hostname, default=localhost
    -u [username]       username (mandatory)
    -p [password]       password (mandatory)
    -P [port]           connection port, default=3306
    -f [dir_path_to_files]        path to attached files directory
    -r [dir_path_to_file_backup]  path to attached files backup directory
    -m [dir_path_to_dump]         path to dump backup directory
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


## set options
while getopts "hv:d:h:u:p:P:f:r:m:" opt
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
			dbname=$OPTARG
			;;
		h)
			hostname=$OPTARG
			;;
		u)
			username=$OPTARG
			;;
		p)
			password=$OPTARG
			;;
		P)
			port=$OPTARG
			;;
		f)
			dir_files=$OPTARG
			;;
		r)
			dir_backup_files=$OPTARG
			;;
		m)
			dir_backup_dumps=$OPTARG
			;;

	esac
done
shift $((OPTIND-1))

## check options
if [ -z $log_level ]
then
	log_level=0
fi

if [ -z $dbname ]
then
	echo "missing dbname, set this option with -d"
	exit 0
fi

if [ -z $hostname ]
then
	hostname="localhost"
fi

if [ -z $username ]
then
	echo "missing username, set this option with -u"
	exit 0
fi

if [ -z $password ]
then
	echo "missing password, set this option with -p"
	exit 0
fi

if [ -z $port ]
then
	port=3306
fi

if [[ -z "$dir_files" || ! -d "$dir_files" ]]
then
	echo "files directory not set (-f) or does not exist: ${dir_files}"
	exit 0
fi

if [[ -z "$dir_backup_files" || ! -d "$dir_backup_files" ]]
then
	echo "backup file directory not set (-r) or does not exist: ${dir_backup_files}"
	exit 0
fi

if [[ -z "$dir_backup_dumps" || ! -d "$dir_backup_dumps" ]]
then
	echo "backup dump directory not set (-m) or does not exist: ${dir_backup_dumps}"
	exit 0
fi

log "info" "redmine backup started"

log "info" "mysqldump started"

timestamp=`date "+%F"`
dump=$dir_backup_dumps/$dbname-$timestamp.gz

mysqldump -u ${username} -h ${hostname} -P ${port} -p${password} ${dbname} | gzip > ${dump}

log "info" "mysqldump finished; dump saved in ${dump}"

tmpfile=$(mktemp)
ls -tr "${dir_backup_dumps}/${dbname}"*>${tmpfile}
## check the availability of 3 dumps (the old to remove, 
## the new just created, the intermediate to keep)
nb_dumps=`wc -l ${tmpfile} | cut -f1 -d" "`
if [ "${nb_dumps}" -lt 3 ]
then
	log "error" "dumps deletion error for ${dbname}, missing previous dumps"
else
	old_dump=`head -n 1 ${tmpfile}`
log "info" "removing old dump: ${old_dump}"
rm "${old_dump}"
fi

log "info" "attachment files rsync started"
rsync -a ${dir_files} ${dir_backup_files}
log "info" "attachment files rsync finished"

log "info" "redmine backup finished"
