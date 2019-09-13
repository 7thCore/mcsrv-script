#!/bin/bash

#Interstellar Rift server script by 7thCore
#If you do not know what any of these settings are you are better off leaving them alone. One thing might brake the other if you fiddle around with it.
#Leave this variable alone, it is tied in with the systemd service file so it changes accordingly by it.
export VERSION="201909131315"

#Basics
export NAME="McSrv" #Name of the screen
if [ "$EUID" -ne "0" ]; then #Check if script executed as root and asign the username for the installation process, otherwise use the executing user
	USER="$(whoami)"
else
	echo "WARNING: Installation mode"
	read -p "Please enter username (default minecraft):" USER #Enter desired username that will be used when creating the new user
	USER=${USER:=minecraft} #If no username was given, use default
fi
#Server configuration
SERVICE_NAME="mcsrv" #Name of the service files, script and script log
SRV_DIR="/home/$USER/server" #Location of the server located on your hdd/ssd
SCRIPT_NAME="$SERVICE_NAME-script.bash" #Script name
SCRIPT_DIR="/home/$USER/scripts" #Location of this script
SERVER_SYNC="/home/$USER/serversync"

if [ -f "$SCRIPT_DIR/$SERVICE_NAME-config.conf" ] ; then
	#Email configuration
	EMAIL_SENDER=$(cat $SCRIPT_DIR/$SERVICE_NAME-config.conf | grep email_sender | cut -d = -f2) #Send emails from this address
	EMAIL_RECIPIENT=$(cat $SCRIPT_DIR/$SERVICE_NAME-config.conf | grep email_recipient | cut -d = -f2) #Send emails to this address
	EMAIL_CRASH=$(cat $SCRIPT_DIR/$SERVICE_NAME-config.conf | grep email_crash | cut -d = -f2) #Send emails when the server crashes
	
	#Ramdisk configuration
	TMPFS_ENABLE=$(cat $SCRIPT_DIR/$SERVICE_NAME-config.conf | grep tmpfs_enable | cut -d = -f2) #Get configuration for tmpfs
else
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Configuration) The configuration is missing. Did you execute script installation?"
fi

#Ramdisk configuration
TMPFS_DIR="/mnt/tmpfs/$USER" #Locaton of your ramdisk. Note: you have to configure the ramdisk in /etc/fstab before using this.

#TmpFs/hdd variables
if [[ "$TMPFS_ENABLE" == "1" ]]; then
	BCKP_SRC_DIR="$TMPFS_DIR/" #Application data of the tmpfs
	JAR_FILE=$(ls -v $TMPFS_DIR | grep -i "forge-.*\.jar" | head -n 1)
	SERVICE="$SERVICE_NAME-tmpfs.service" #TmpFs service file name
else
	BCKP_SRC_DIR="$SRV_DIR/" #Application data of the hdd/ssd
	JAR_FILE=$(ls -v $SRV_DIR | grep -i "forge-.*\.jar" | head -n 1)
	SERVICE="$SERVICE_NAME.service" #Hdd/ssd service file name
fi

#Backup configuration
BCKP_SRC="config mods scripts banned-ips.json banned-players.json ops.json server.properties whitelist.json $JAR_FILE" #What files to backup, * for all
BCKP_WORLD="Biomes Bundle"
BCKP_DIR="/home/$USER/backups" #Location of stored backups
BCKP_DEST="$BCKP_DIR/$(date +"%Y")/$(date +"%m")/$(date +"%d")" #How backups are sorted, by default it's sorted in folders by month and day
BCKP_DELOLD="+3" #Delete old backups. Ex +3 deletes 3 days old backups.

#Log configuration
export LOG_DIR="/home/$USER/logs/$(date +"%Y")/$(date +"%m")/$(date +"%d")"
export LOG_SCRIPT="$LOG_DIR/$SERVICE_NAME-script.log" #Script log
export LOG_TMP="/tmp/$SERVICE_NAME-screen.log"
LOG_DELOLD="+7" #Delete old logs. Ex +14 deletes 14 days old logs.

TIMEOUT=120

#-------Do not edit anything beyond this line-------

#Console collors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
LIGHTRED='\033[1;31m'
NC='\033[0m'

#Deletes old logs
script_logs() {
	#If there is not a folder for today, create one
	if [ ! -d "$LOG_DIR" ]; then
		mkdir -p $LOG_DIR
	fi
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Delete old logs) Deleting old logs: $LOG_DELOLD days old." | tee -a  "$LOG_SCRIPT"
	# Delete old logs
	find $LOG_DIR/* -mtime $LOG_DELOLD -exec rm {} \;
	# Delete empty folders
	#find $LOG_DIR/ -type d 2> /dev/null -empty -exec rm -rf {} \;
	find $LOG_DIR/ -type d -empty -delete
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Delete old logs) Deleting old logs complete." | tee -a  "$LOG_SCRIPT"
}

#Prints out if the server is running
script_status() {
	if [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "inactive" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Status) Server is not running." | tee -a "$LOG_SCRIPT"
	elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "active" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Status) Server running." | tee -a "$LOG_SCRIPT"
	elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "failed" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Status) Server is in failed state. Please check logs." | tee -a "$LOG_SCRIPT"
	elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "activating" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Status) Server is activating. Please wait." | tee -a "$LOG_SCRIPT"
	elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "deactivating" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Status) Server is in deactivating. Please wait." | tee -a "$LOG_SCRIPT"
	fi
}

#If the script variable is set to 0, the script won't issue any commands ran. It will just exit.
script_enabled() {
	if [[ "$SCRIPT_ENABLED" == "0" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Script status) Server script is disabled" | tee -a  "$LOG_SCRIPT"
		script_status
		exit 0
	fi
}

#Systemd service sends email if email notifications for crashes enabled
script_send_crash_email() {
	if [[ "$EMAIL_CRASH" == "1" ]]; then
		systemctl --user status $SERVICE > $LOG_DIR/service_log.txt
		zip -j $LOG_DIR/service_logs.zip $LOG_DIR/service_log.txt
		zip -j $LOG_DIR/script_logs.zip $LOG_SCRIPT
		mail -a $LOG_DIR/service_logs.zip -a $LOG_DIR/script_logs.zip -a -r "$EMAIL_SENDER ($NAME $USER)" -s "Notification: Crash" $EMAIL_RECIPIENT <<- EOF
		The server crashed 3 times in the last 5 minutes. Automatic restart is disabled and the server is inactive. Please check the logs for more information.
		
		Attachment contents:
		service_logs.zip - Logs from the systemd service
		script_logs.zip - Logs from the script
		
		DO NOT SEND ANY OF THESE TO THE DEVS!
		
		Contact the script developer 7thCore on discord for help regarding any problems the script may have caused.
		EOF
		rm $LOG_DIR/service_log.txt
		rm -rf $LOG_DIR/*.zip
	fi
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Crash) Server crashed. Please review your logs." | tee -a "$LOG_SCRIPT"
}

#Enable automatic world saving
script_saveon() {
	if [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "inactive" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Save) Server is not running." | tee -a "$LOG_SCRIPT"
	elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "failed" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Save) Server is in failed state. Aborting save." | tee -a "$LOG_SCRIPT"
	elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "activating" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Save) Server is activating. Aborting save." | tee -a "$LOG_SCRIPT"
	elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "deactivating" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Save) Server is in deactivating. Aborting save." | tee -a "$LOG_SCRIPT"
	elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "active" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Save on) Activating autosaving." | tee -a  "$LOG_SCRIPT"
		( sleep 5 && screen -p 0 -S $NAME -X eval 'stuff "save-on"\\015' ) &
		timeout $TIMEOUT /bin/bash -c '
		while read line; do
			if [[ "$line" =~ "[Server thread/INFO] [minecraft/DedicatedServer]: Turned on world auto-saving" ]]; then
				echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Save on) Autosaving has been Activated." | tee -a  "$LOG_SCRIPT"
				screen -p 0 -S $NAME -X eval 'stuff "say Automatic world saving is enabled."\\015'
				break
			else
				echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Save on) Activating autosaving. Please wait..."
			fi
		done < <(tail -n1 -f $LOG_TMP)'
	fi
}

#Disable automatic world saving
script_saveoff() {
	if [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "inactive" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Save) Server is not running." | tee -a "$LOG_SCRIPT"
	elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "failed" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Save) Server is in failed state. Aborting save." | tee -a "$LOG_SCRIPT"
	elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "activating" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Save) Server is activating. Aborting save." | tee -a "$LOG_SCRIPT"
	elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "deactivating" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Save) Server is in deactivating. Aborting save." | tee -a "$LOG_SCRIPT"
	elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "active" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Save off) Deactivating autosaving." | tee -a  "$LOG_SCRIPT"
		( sleep 5 && screen -p 0 -S $NAME -X eval 'stuff "save-off"\\015' ) &
		timeout $TIMEOUT /bin/bash -c '
		while read line; do
			if [[ "$line" =~ "[Server thread/INFO] [minecraft/DedicatedServer]: Turned off world auto-saving" ]]; then
				echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Save off) Autosaving has been deactivated." | tee -a  "$LOG_SCRIPT"
				screen -p 0 -S $NAME -X eval 'stuff "say Automatic world saving is disabled."\\015'
				break
			else
				echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Save off) Deactivating autosaving. Please wait..."
			fi
		done < <(tail -n1 -f $LOG_TMP)'
	fi
}

#Issue the save command to the server
script_save() {
	if [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "inactive" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Save) Server is not running." | tee -a "$LOG_SCRIPT"
	elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "failed" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Save) Server is in failed state. Aborting save." | tee -a "$LOG_SCRIPT"
	elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "activating" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Save) Server is activating. Aborting save." | tee -a "$LOG_SCRIPT"
	elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "deactivating" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Save) Server is in deactivating. Aborting save." | tee -a "$LOG_SCRIPT"
	elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "active" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Save) Save game to disk has been initiated." | tee -a  "$LOG_SCRIPT"
		( sleep 5 && screen -p 0 -S $NAME -X eval 'stuff "save-all"\\015' ) &
		timeout $TIMEOUT /bin/bash -c '
		while read line; do
			if [[ "$line" =~ "[Server thread/INFO] [minecraft/DedicatedServer]: Saved the world" ]]; then
				echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Save) Save game to disk has been completed." | tee -a  "$LOG_SCRIPT"
				screen -p 0 -S $NAME -X eval 'stuff "say World save complete."\\015'
				break
			else
				echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Save) Save game to disk is in progress. Please wait..."
			fi
		done < <(tail -n1 -f $LOG_TMP)'
	fi
}

#Clear all drops in the world
script_cleardrops() {
	if [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "inactive" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Clear drops) Server is not running." | tee -a "$LOG_SCRIPT"
	elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "failed" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Clear drops) Server is in failed state. Aborting clear drops." | tee -a "$LOG_SCRIPT"
	elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "activating" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Clear drops) Server is activating. Aborting Clear drops." | tee -a "$LOG_SCRIPT"
	elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "deactivating" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Clear drops) Server is in deactivating. Aborting clear drops." | tee -a "$LOG_SCRIPT"
	elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "active" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Clear drops) Clearing drops in 1 minute." | tee -a  "$LOG_SCRIPT"
		( sleep 5 &&
		screen -p 0 -S $NAME -X eval 'stuff "say Warning! Clearing all drops in 1 minutes!"\015' &&
		sleep 30 &&
		screen -p 0 -S $NAME -X eval 'stuff "say Warning! Clearing all drops in 30 seconds!"\015' &&
		sleep 15 &&
		screen -p 0 -S $NAME -X eval 'stuff "say Warning! Clearing all drops in 15 seconds!"\015' &&
		sleep 5 &&
		screen -p 0 -S $NAME -X eval 'stuff "say Warning! Clearing all drops in 10 seconds!"\015' &&
		sleep 5 &&
		screen -p 0 -S $NAME -X eval 'stuff "say Warning! Clearing all drops in 5 seconds!"\015' &&
		sleep 1 &&
		screen -p 0 -S $NAME -X eval 'stuff "say Warning! Clearing all drops in 4 seconds!"\015' &&
		sleep 1 &&
		screen -p 0 -S $NAME -X eval 'stuff "say Warning! Clearing all drops in 3 seconds!"\015' &&
		sleep 1 &&
		screen -p 0 -S $NAME -X eval 'stuff "say Warning! Clearing all drops in 2 seconds!"\015' &&
		sleep 1 &&
		screen -p 0 -S $NAME -X eval 'stuff "say Warning! Clearing all drops in 1 seconds!"\015' &&
		sleep 1 &&
		screen -p 0 -S $NAME -X eval 'stuff "say Clearing drops."\015' &&
		screen -p 0 -S $NAME -X eval 'stuff "/kill @e[type=item]"\015' &&
		sleep 1 ) &
		timeout $TIMEOUT /bin/bash -c '
		while read line; do
			if [[ "$line" =~ "/kill @e[type=item]" ]]; then
				echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Clear Drops) Clearing drops complete." | tee -a  "$LOG_SCRIPT"
				screen -p 0 -S $NAME -X eval 'stuff "say Clearing drops complete."\015'
				break
			else
				echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Clear Drops) Clearing drops in progress. Please wait..."
			fi
		done < <(tail -n1 -f $LOG_TMP)'
	fi
}

#Sync server files from ramdisk to hdd/ssd
script_sync() {
	if [[ "$TMPFS_ENABLE" == "1" ]]; then
		if [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "inactive" ]]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Sync) Server is not running." | tee -a "$LOG_SCRIPT"
		elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "failed" ]]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Sync) Server is in failed state. Aborting sync." | tee -a "$LOG_SCRIPT"
		elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "activating" ]]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Sync) Server is activating. Aborting sync." | tee -a "$LOG_SCRIPT"
		elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "deactivating" ]]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Sync) Server is in deactivating. Aborting sync." | tee -a "$LOG_SCRIPT"
		elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "active" ]]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Sync) Sync from tmpfs to disk has been initiated." | tee -a  "$LOG_SCRIPT"
			rsync -av --info=progress2 $TMPFS_DIR/ $SRV_DIR #| sed -e "s/^/$(date +"%Y-%m-%d %H:%M:%S") [$NAME] [INFO] (Sync) Syncing: /" | tee -a  "$LOG_SCRIPT"
			sleep 1
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Sync) Sync from tmpfs to disk has been completed." | tee -a  "$LOG_SCRIPT"
			screen -p 0 -S $NAME -X eval 'stuff "say File sync complete."\\015'
		fi
	elif [[ "$TMPFS_ENABLE" == "0" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Sync) Server does not have tmpfs enabled." | tee -a  "$LOG_SCRIPT"
	fi
}

#Start the server
script_start() {
	if [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "inactive" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server start initialized." | tee -a  "$LOG_SCRIPT"
		systemctl --user start $SERVICE
		sleep 1
		while [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "activating" ]]; do
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server is activating. Please wait..." | tee -a  "$LOG_SCRIPT"
			sleep 1
		done
		if [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "active" ]]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server has been successfully activated." | tee -a  "$LOG_SCRIPT"
			sleep 1
		elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" != "active" ]]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server failed to activate. See systemctl --user status $SERVICE for details." | tee -a  "$LOG_SCRIPT"
			sleep 1
		fi
	elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "active" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server is already running." | tee -a  "$LOG_SCRIPT"
		sleep 1
	elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "failed" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server failed to activate. See systemctl --user status $SERVICE for details." | tee -a  "$LOG_SCRIPT"
		sleep 1
	fi
}

#Stop the server
script_stop() {
	if [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "inactive" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Stop) Server is not running." | tee -a  "$LOG_SCRIPT"
		sleep 1
	elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "active" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Stop) Server shutdown in progress." | tee -a  "$LOG_SCRIPT"
		systemctl --user stop $SERVICE
		sleep 1
		while [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "deactivating" ]]; do
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Stop) Server is deactivating. Please wait..." | tee -a  "$LOG_SCRIPT"
			sleep 1
		done
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Stop) Server is deactivated." | tee -a  "$LOG_SCRIPT"
	fi
}

#Restart the server
script_restart() {
	if [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "inactive" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Restart) Server is not running. Use -start to start the server." | tee -a "$LOG_SCRIPT"
	elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "activating" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Restart) Server is activating. Aborting restart." | tee -a "$LOG_SCRIPT"
	elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "deactivating" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Restart) Server is in deactivating. Aborting restart." | tee -a "$LOG_SCRIPT"
	elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "active" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Restart) Server is going to restart in 15-30 seconds, please wait..." | tee -a "$LOG_SCRIPT"
		sleep 1
		screen -p 0 -S $NAME -X eval 'stuff "/say Server restarting in 15 seconds."\\015'
		sleep 15
		script_stop
		sleep 1
		script_start
		sleep 1
	fi
}

#Deletes old backups
script_deloldbackup() {
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Delete old backup) Deleting old backups: $BCKP_DELOLD days old." | tee -a  "$LOG_SCRIPT"
	# Delete old backups
	find $BCKP_DIR/* -mtime $BCKP_DELOLD -exec rm {} \;
	# Delete empty folders
	#find $BCKP_DIR/ -type d 2> /dev/null -empty -exec rm -rf {} \;
	find $BCKP_DIR/ -type d -empty -delete
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Delete old backup) Deleting old backups complete." | tee -a  "$LOG_SCRIPT"
}

#Backs up the server
script_backup() {
	#If there is not a folder for today, create one
	if [ ! -d "$BCKP_DEST" ]; then
		mkdir -p $BCKP_DEST
	fi
	#Backup source to destination
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Backup) Backup has been initiated." | tee -a  "$LOG_SCRIPT"
	cd "$BCKP_SRC_DIR"
	tar -cpvzf $BCKP_DEST/$(date +"%Y%m%d%H%M").tar.gz $BCKP_SRC "$BCKP_WORLD" #| sed -e "s/^/$(date +"%Y-%m-%d %H:%M:%S") [$NAME] [INFO] (Backup) Compressing: /" | tee -a  "$LOG_SCRIPT"
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Backup) Backup complete." | tee -a  "$LOG_SCRIPT"
}

#Automaticly backs up the server and deletes old backups
script_autobackup() {
	if [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" != "active" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Autobackup) Server is not running." | tee -a  "$LOG_SCRIPT"
	elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "active" ]]; then
		screen -p 0 -S $NAME -X eval 'stuff "/say Server backup in progress."\\015'
		sleep 1
		script_backup
		sleep 1
		script_deloldbackup
		screen -p 0 -S $NAME -X eval 'stuff "/say Server backup complete."\\015'

	fi
}

#Delete server save
script_delete_save() {
	if [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" != "active" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Delete save) WARNING! This will delete the server's save game." | tee -a "$LOG_SCRIPT"
		read -p "Are you sure you want to delete the server's save game? (y/n): " DELETE_SERVER_SAVE
		if [[ "$DELETE_SERVER_SAVE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
			read -p "Do you also want to delete the server.json and SSK.txt? (y/n): " DELETE_SERVER_SSKJSON
			if [[ "$DELETE_SERVER_SSKJSON" =~ ^([yY][eE][sS]|[yY])$ ]]; then
				if [[ "$TMPFS_ENABLE" == "1" ]]; then
					rm -rf $TMPFS_DIR
				fi
				rm -rf "$SRV_DIR/$WINE_PREFIX_GAME_CONFIG"/*
				echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Delete save) Deletion of save files, server.json and SSK.txt complete." | tee -a "$LOG_SCRIPT"
			elif [[ "$DELETE_SERVER_SSKJSON" =~ ^([nN][oO]|[nN])$ ]]; then
				if [[ "$TMPFS_ENABLE" == "1" ]]; then
					rm -rf $TMPFS_DIR
				fi
				cd "$SRV_DIR/$WINE_PREFIX_GAME_CONFIG"
				rm -rf $(ls | grep -v server.json | grep -v SSK.txt)
				echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Delete save) Deletion of save files complete. SSK and server.json are untouched." | tee -a "$LOG_SCRIPT"
			fi
		elif [[ "$DELETE_SERVER_SAVE" =~ ^([nN][oO]|[nN])$ ]]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Delete save) Save deletion canceled." | tee -a "$LOG_SCRIPT"
		fi
	elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "active" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Clear save) The server is running. Aborting..." | tee -a "$LOG_SCRIPT"
	fi
}

#Install or reinstall systemd services
script_install_services() {
	if [ "$EUID" -ne "0" ]; then #Check if script executed as root and asign the username for the installation process, otherwise use the executing user
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Reinstall systemd services) Systemd services reinstallation commencing. Waiting on user configuration." | tee -a "$LOG_SCRIPT"
		read -p "Are you sure you want to reinstall the systemd services? (y/n): " REINSTALL_SYSTEMD_SERVICES
		if [[ "$REINSTALL_SYSTEMD_SERVICES" =~ ^([yY][eE][sS]|[yY])$ ]]; then
			INSTALL_SYSTEMD_SERVICES_STATE="1"
		elif [[ "$REINSTALL_SYSTEMD_SERVICES" =~ ^([nN][oO]|[nN])$ ]]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Reinstall systemd services) Systemd services reinstallation aborted." | tee -a "$LOG_SCRIPT"
			INSTALL_SYSTEMD_SERVICES_STATE="0"
		fi
	else
		INSTALL_SYSTEMD_SERVICES_STATE="1"
	fi
	
	if [[ "$INSTALL_SYSTEMD_SERVICES_STATE" == "1" ]]; then
		if [ -f "/home/$USER/.config/systemd/user/$SERVICE_NAME-mkdir-tmpfs.service" ]; then
			rm /home/$USER/.config/systemd/user/$SERVICE_NAME-mkdir-tmpfs.service
		fi
		
		if [ -f "/home/$USER/.config/systemd/user/$SERVICE_NAME-tmpfs.service" ]; then
			rm /home/$USER/.config/systemd/user/$SERVICE_NAME-tmpfs.service
		fi
		
		if [ -f "/home/$USER/.config/systemd/user/$SERVICE_NAME.service" ]; then
			rm /home/$USER/.config/systemd/user/$SERVICE_NAME.service
		fi
		
		if [ -f "/home/$USER/.config/systemd/user/$SERVICE_NAME-timer-1.timer" ]; then
			rm /home/$USER/.config/systemd/user/$SERVICE_NAME-timer-1.timer
		fi
		
		if [ -f "/home/$USER/.config/systemd/user/$SERVICE_NAME-timer-1.service" ]; then
			rm /home/$USER/.config/systemd/user/$SERVICE_NAME-timer-1.service
		fi
		
		if [ -f "/home/$USER/.config/systemd/user/$SERVICE_NAME-timer-2.timer" ]; then
			rm /home/$USER/.config/systemd/user/$SERVICE_NAME-timer-2.timer
		fi
		
		if [ -f "/home/$USER/.config/systemd/user/$SERVICE_NAME-timer-2.service" ]; then
			rm /home/$USER/.config/systemd/user/$SERVICE_NAME-timer-2.service
		fi
		
		if [ -f "/home/$USER/.config/systemd/user/$SERVICE_NAME-serversync.service" ]; then
			rm /home/$USER/.config/systemd/user/$SERVICE_NAME-serversync.service
		fi
		
		cat > /home/$USER/.config/systemd/user/$SERVICE_NAME-mkdir-tmpfs.service <<- EOF
		[Unit]
		Description=$NAME TmpFs dir creator
		After=mnt-tmpfs.mount
		
		[Service]
		Type=oneshot
		WorkingDirectory=/home/$USER/
		ExecStart=/bin/mkdir -p $TMPFS_DIR/$WINE_PREFIX_GAME_DIR/Build
		
		[Install]
		WantedBy=default.target
		EOF
		
		cat > /home/$USER/.config/systemd/user/$SERVICE_NAME-tmpfs.service <<- EOF
		[Unit]
		Description=Minecraft Server Service
		Requires=$SERVICE_NAME-mkdir-tmpfs.service
		After=network.target mnt-tmpfs.mount $SERVICE_NAME-mkdir-tmpfs.service
		Conflicts=$SERVICE_NAME.service
		StartLimitBurst=3
		StartLimitIntervalSec=300
		StartLimitAction=none
		OnFailure=$SERVICE_NAME-send-email.service
		
		[Service]
		Type=forking
		WorkingDirectory=$TMPFS_DIR
		ExecStartPre=/usr/bin/rsync -av --info=progress2 $SRV_DIR/ $TMPFS_DIR
		EOF
		echo "ExecStart=/bin/bash -c 'screen -c "$SCRIPT_DIR/$SERVICE_NAME"-screen.conf -d -m -S "$NAME" java -server -XX:+UseG1GC -Xmx6G -Xms1G -Dsun.rmi.dgc.server.gcInterval=2147483646 -XX:+UnlockExperimentalVMOptions -XX:G1NewSizePercent=20 -XX:G1ReservePercent=20 -XX:MaxGCPauseMillis=50 -XX:G1HeapRegionSize=32M -Dfml.ignorePatchDiscrepancies=true -Dfml.ignoreInvalidMinecraftCertificates=true -jar"' $(ls -v '$TMPFS_DIR' | grep -i "forge-.*\.jar" | head -n 1) nogui'\' >> /home/$USER/.config/systemd/user/$SERVICE_NAME-tmpfs.service
		cat >> /home/$USER/.config/systemd/user/$SERVICE_NAME-tmpfs.service <<- EOF
		ExecStop=/usr/bin/screen -p 0 -S $NAME -X eval 'stuff "say SERVER SHUTTING DOWN IN 10!"\\015'
		ExecStop=/usr/bin/sleep 5
		ExecStop=/usr/bin/screen -p 0 -S $NAME -X eval 'stuff "say SERVER SHUTTING DOWN IN 5!"\\015'
		ExecStop=/usr/bin/sleep 5
		ExecStop=/usr/bin/screen -p 0 -S $NAME -X eval 'stuff "say SERVER SHUTTING DOWN NOW!"\\015'
		ExecStop=/usr/bin/screen -p 0 -S $NAME -X eval 'stuff "save-all"\\015'
		ExecStop=/usr/bin/screen -p 0 -S $NAME -X eval 'stuff "stop"\\015'
		ExecStop=/usr/bin/sleep 10
		ExecStop=/usr/bin/rsync -av --info=progress2 $TMPFS_DIR/ $SRV_DIR
		TimeoutStartSec=infinity
		TimeoutStopSec=120
		RestartSec=10
		Restart=on-failure
		
		[Install]
		WantedBy=default.target
		EOF
		
		cat > /home/$USER/.config/systemd/user/$SERVICE_NAME.service <<- EOF
		[Unit]
		Description=Minecraft Server Service
		After=network.target
		Conflicts=$SERVICE_NAME-tmpfs.service
		StartLimitBurst=3
		StartLimitIntervalSec=300
		StartLimitAction=none
		OnFailure=$SERVICE_NAME-send-email.service
		
		[Service]
		Type=forking
		WorkingDirectory=$SRV_DIR
		EOF
		echo "ExecStart=/bin/bash -c 'screen -c "$SCRIPT_DIR/$SERVICE_NAME"-screen.conf -d -m -S "$NAME" java -server -XX:+UseG1GC -Xmx6G -Xms1G -Dsun.rmi.dgc.server.gcInterval=2147483646 -XX:+UnlockExperimentalVMOptions -XX:G1NewSizePercent=20 -XX:G1ReservePercent=20 -XX:MaxGCPauseMillis=50 -XX:G1HeapRegionSize=32M -Dfml.ignorePatchDiscrepancies=true -Dfml.ignoreInvalidMinecraftCertificates=true -jar"' $(ls -v '$SRV_DIR' | grep -i "forge-.*\.jar" | head -n 1) nogui'\' >> /home/$USER/.config/systemd/user/$SERVICE_NAME.service
		cat >> /home/$USER/.config/systemd/user/$SERVICE_NAME.service <<- EOF
		ExecStop=/usr/bin/screen -p 0 -S $NAME -X eval 'stuff "say SERVER SHUTTING DOWN IN 10!"\\015'
		ExecStop=/usr/bin/sleep 5
		ExecStop=/usr/bin/screen -p 0 -S $NAME -X eval 'stuff "say SERVER SHUTTING DOWN IN 5!"\\015'
		ExecStop=/usr/bin/sleep 5
		ExecStop=/usr/bin/screen -p 0 -S $NAME -X eval 'stuff "say SERVER SHUTTING DOWN NOW!"\\015'
		ExecStop=/usr/bin/screen -p 0 -S $NAME -X eval 'stuff "save-all"\\015'
		ExecStop=/usr/bin/screen -p 0 -S $NAME -X eval 'stuff "stop"\\015'
		ExecStop=/usr/bin/sleep 10
		TimeoutStartSec=infinity
		TimeoutStopSec=120
		RestartSec=10
		Restart=on-failure
		
		[Install]
		WantedBy=default.target
		EOF
		
		cat > /home/$USER/.config/systemd/user/$SERVICE_NAME-timer-1.timer <<- EOF
		[Unit]
		Description=$NAME Script Timer 1
		
		[Timer]
		OnCalendar=*-*-* 00:00:00
		OnCalendar=*-*-* 06:00:00
		OnCalendar=*-*-* 12:00:00
		OnCalendar=*-*-* 18:00:00
		Persistent=true
		
		[Install]
		WantedBy=timers.target
		EOF
		
		cat > /home/$USER/.config/systemd/user/$SERVICE_NAME-timer-1.service <<- EOF
		[Unit]
		Description=$NAME Script Timer 1 Service
		
		[Service]
		Type=oneshot
		ExecStart=$SCRIPT_DIR/$SCRIPT_NAME -timer_one
		EOF
		
		cat > /home/$USER/.config/systemd/user/$SERVICE_NAME-timer-2.timer <<- EOF
		[Unit]
		Description=$NAME Script Timer 2
		
		[Timer]
		OnCalendar=*-*-* *:15:00
		OnCalendar=*-*-* *:30:00
		OnCalendar=*-*-* *:45:00
		OnCalendar=*-*-* 01:00:00
		OnCalendar=*-*-* 02:00:00
		OnCalendar=*-*-* 03:00:00
		OnCalendar=*-*-* 04:00:00
		OnCalendar=*-*-* 05:00:00
		OnCalendar=*-*-* 07:00:00
		OnCalendar=*-*-* 08:00:00
		OnCalendar=*-*-* 09:00:00
		OnCalendar=*-*-* 10:00:00
		OnCalendar=*-*-* 11:00:00
		OnCalendar=*-*-* 13:00:00
		OnCalendar=*-*-* 14:00:00
		OnCalendar=*-*-* 15:00:00
		OnCalendar=*-*-* 16:00:00
		OnCalendar=*-*-* 17:00:00
		OnCalendar=*-*-* 19:00:00
		OnCalendar=*-*-* 20:00:00
		OnCalendar=*-*-* 21:00:00
		OnCalendar=*-*-* 22:00:00
		OnCalendar=*-*-* 23:00:00
		Persistent=true
		
		[Install]
		WantedBy=timers.target
		EOF
		
		cat > /home/$USER/.config/systemd/user/$SERVICE_NAME-timer-2.service <<- EOF
		[Unit]
		Description=$NAME Script Timer 2 Service
		
		[Service]
		Type=oneshot
		ExecStart=$SCRIPT_DIR/$SCRIPT_NAME -timer_two
		EOF
		
		cat > /home/$USER/.config/systemd/user/$SERVICE_NAME-timer-3.timer <<- EOF
		[Unit]
		Description=$NAME Script Timer 3 (Auto update script from github)
		
		[Timer]
		OnCalendar=*-*-* 23:55:00
		Persistent=true
		
		[Install]
		WantedBy=timers.target
		EOF
		
		cat > /home/$USER/.config/systemd/user/$SERVICE_NAME-timer-3.service <<- EOF
		[Unit]
		Description=$NAME Script Timer 3 Service (Auto update script from github)
		
		[Service]
		Type=oneshot
		ExecStart=$SCRIPT_DIR/$SERVICE_NAME-update.bash -update
		EOF
		
		cat > /home/$USER/.config/systemd/user/$SERVICE_NAME-serversync.service <<- EOF
		[Unit]
		Description=Minecraft Server Sync Service
		After=network.target

		[Service]
		Type=forking
		WorkingDirectory=$SERVER_SYNC
		EOF
		echo "ExecStart=/bin/bash -c 'screen -d -m -S ServerSync java -jar "'$(ls -v '$SERVER_SYNC' | grep -i "serversync" | head -n 1) server'\' >> /home/$USER/.config/systemd/user/$SERVICE_NAME-serversync.service
		cat >> /home/$USER/.config/systemd/user/$SERVICE_NAME-serversync.service <<- EOF
		ExecStop=/usr/bin/screen -X -S ServerSync quit

		Restart=on-failure
		RestartSec=60

		[Install]
		WantedBy=default.target
		EOF
		
		cat > /home/$USER/.config/systemd/user/$SERVICE_NAME-send-email.service <<- EOF
		[Unit]
		Description=$NAME Script Send Email notification Service
		
		[Service]
		Type=oneshot
		ExecStart=$SCRIPT_DIR/$SCRIPT_NAME -send_crash_email
		EOF
	fi
	
	if [ "$EUID" -ne "0" ]; then
		if [[ "$INSTALL_SYSTEMD_SERVICES_STATE" == "1" ]]; then
			systemctl --user daemon-reload
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Reinstall systemd services) Systemd services reinstallation complete." | tee -a "$LOG_SCRIPT"
		fi
	fi
}

#Install or reinstall the update script
script_install_update_script() {
	if [ "$EUID" -ne "0" ]; then #Check if script executed as root and asign the username for the installation process, otherwise use the executing user
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Reinstall update script) Systemd services reinstallation commencing. Waiting on user configuration." | tee -a "$LOG_SCRIPT"
		read -p "Are you sure you want to reinstall the update script? (y/n): " REINSTALL_UPDATE_SCRIPT
		if [[ "$REINSTALL_UPDATE_SCRIPT" =~ ^([yY][eE][sS]|[yY])$ ]]; then
			INSTALL_UPDATE_SCRIPT_STATE="1"
		elif [[ "$REINSTALL_UPDATE_SCRIPT" =~ ^([nN][oO]|[nN])$ ]]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Reinstall update script) Systemd services reinstallation aborted." | tee -a "$LOG_SCRIPT"
			INSTALL_UPDATE_SCRIPT_STATE="0"
		fi
	else
		INSTALL_UPDATE_SCRIPT_STATE="1"
	fi
	
	if [[ "$INSTALL_UPDATE_SCRIPT_STATE" == "1" ]]; then
		if [ -f "/$SCRIPT_DIR/$SERVICE_NAME-update.bash" ]; then
			rm /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		fi
		
		echo '#!/bin/bash' > /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo 'NAME=$(cat '"$SCRIPT_DIR/$SCRIPT_NAME"' | grep -m 1 NAME | cut -d \" -f2)' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo 'SERVICE_NAME=$(cat '"$SCRIPT_DIR/$SCRIPT_NAME"' | grep -m 1 SERVICE_NAME | cut -d \" -f2)' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo 'LOG_DIR="/home/'"$USER"'/logs/$(date +"%Y")/$(date +"%m")/$(date +"%d")"' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo 'LOG_SCRIPT="$LOG_DIR/$SERVICE_NAME-script.log" #Script log' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo 'script_update() {' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '	git clone https://github.com/7thCore/'"$SERVICE_NAME"'-script /tmp/'"$SERVICE_NAME"'-script' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '	INSTALLED=$(cat '"$SCRIPT_DIR/$SCRIPT_NAME"' | grep -m 1 VERSION | cut -d \" -f2)' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '	AVAILABLE=$(cat /tmp/'"$SERVICE_NAME"'-script/'"$SERVICE_NAME"'-script.bash | grep -m 1 VERSION | cut -d \" -f2)' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '	if [ "$AVAILABLE" -gt "$INSTALLED" ]; then' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '		echo "$(date +"%Y-%m-%d %H:%M:%S") [$INSTALLED] [$NAME] [INFO] (Script update) Script update detected." | tee -a $LOG_SCRIPT' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '		echo "$(date +"%Y-%m-%d %H:%M:%S") [$INSTALLED] [$NAME] [INFO] (Script update) Installed:$INSTALLED, Available:$AVAILABLE" | tee -a $LOG_SCRIPT' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '		rm /home/'"$USER"'/scripts/'"$SERVICE_NAME"'-script.bash' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '		cp /tmp/'"$SERVICE_NAME"'-script/'"$SERVICE_NAME"'-script.bash /home/'"$USER"'/scripts/'"$SERVICE_NAME"'-script.bash' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '		chmod +x /home/'"$USER"'/scripts/'"$SERVICE_NAME"'-script.bash' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo ''  >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '		INSTALLED=$(cat '"$SCRIPT_DIR/$SCRIPT_NAME"' | grep -m 1 VERSION | cut -d \" -f2)' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '		AVAILABLE=$(cat /tmp/'"$SERVICE_NAME"'-script/'"$SERVICE_NAME"'-script.bash | grep -m 1 VERSION | cut -d \" -f2)' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '		if [ "$AVAILABLE" -eq "$INSTALLED" ]; then' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '			echo "$(date +"%Y-%m-%d %H:%M:%S") [$INSTALLED] [$NAME] [INFO] (Script update) Script update complete." | tee -a $LOG_SCRIPT' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '		else' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '			echo "$(date +"%Y-%m-%d %H:%M:%S") [$INSTALLED] [$NAME] [INFO] (Script update) Script update failed." | tee -a $LOG_SCRIPT' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '		fi' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '	else' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '		echo "$(date +"%Y-%m-%d %H:%M:%S") [$INSTALLED] [$NAME] [INFO] (Script update) No new script updates detected." | tee -a $LOG_SCRIPT' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '		echo "$(date +"%Y-%m-%d %H:%M:%S") [$INSTALLED] [$NAME] [INFO] (Script update) Installed:$INSTALLED, Available:$AVAILABLE" | tee -a $LOG_SCRIPT' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '	fi' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '	rm -rf /tmp/'"$SERVICE_NAME"'-script' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo "}" >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo 'script_update_force() {' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '	git clone https://github.com/7thCore/'"$SERVICE_NAME"'-script /tmp/'"$SERVICE_NAME"'-script' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '	rm /home/'"$USER"'/scripts/'"$SERVICE_NAME"'-script.bash' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '	cp /tmp/'"$SERVICE_NAME"'-script/'"$SERVICE_NAME"'-script.bash /home/'"$USER"'/scripts/'"$SERVICE_NAME"'-script.bash' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '	chmod +x /home/'"$USER"'/scripts/'"$SERVICE_NAME"'-script.bash' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '	rm -rf /tmp/'"$SERVICE_NAME"'-script' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo "}" >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo 'case "$1" in' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '	-help)' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '		echo -e "${CYAN}Time: $(date +"%Y-%m-%d %H:%M:%S") ${NC}"' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '		echo -e "${CYAN}$NAME server script by 7thCore${NC}"' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '		echo ""' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '		echo -e "${LIGHTRED}The script updates the primary server script from github.${NC}"' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '		echo ""' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '		echo -e "${GREEN}update ${RED}- ${GREEN}Check for script updates and update if available${NC}"' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '		echo -e "${GREEN}force_update ${RED}- ${GREEN}Download latest script version and install it no matter if the installed script is the same version${NC}"' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '		;;' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '	-update)' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '		script_update' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '		;;' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '	-force_update)' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '		script_force_update' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '		;;' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '	*)' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '	echo -e "${CYAN}Time: $(date +"%Y-%m-%d %H:%M:%S") ${NC}"' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '	echo -e "${CYAN}$NAME update script for server script by 7thCore${NC}"' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '	echo ""' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '	echo "For more detailed information, execute the script with the -help argument"' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '	echo ""' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '	echo "Usage: $0 {update|force_update}"' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '	exit 1' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo '	;;' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		echo 'esac' >> /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		
		chmod +x /$SCRIPT_DIR/$SERVICE_NAME-update.bash
		if [ "$EUID" -ne "0" ]; then
			if [[ "$INSTALL_UPDATE_SCRIPT_STATE" == "1" ]]; then
				echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Reinstall update script) Update script reinstallation complete." | tee -a "$LOG_SCRIPT"
			fi
		fi
	fi
}

#First timer function for systemd timers to execute parts of the script in order without interfering with each other
script_timer_one() {
	if [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "inactive" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Status) Server is not running." | tee -a "$LOG_SCRIPT"
	elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "failed" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Status) Server is in failed state. Please check logs." | tee -a "$LOG_SCRIPT"
	elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "activating" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Status) Server is activating. Aborting until next scheduled execution." | tee -a "$LOG_SCRIPT"
	elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "deactivating" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Status) Server is in deactivating. Aborting until next scheduled execution." | tee -a "$LOG_SCRIPT"
	elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "active" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Status) Server running." | tee -a "$LOG_SCRIPT"
		script_enabled
		script_logs
		script_cleardrops
		script_saveoff
		script_save
		script_sync
		script_autobackup
		script_saveon
	fi
}

#Second timer function for systemd timers to execute parts of the script in order without interfering with each other
script_timer_two() {
	if [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "inactive" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Status) Server is not running." | tee -a "$LOG_SCRIPT"
	elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "failed" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Status) Server is in failed state. Please check logs." | tee -a "$LOG_SCRIPT"
	elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "activating" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Status) Server is activating. Aborting until next scheduled execution." | tee -a "$LOG_SCRIPT"
	elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "deactivating" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Status) Server is in deactivating. Aborting until next scheduled execution." | tee -a "$LOG_SCRIPT"
	elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "active" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Status) Server running." | tee -a "$LOG_SCRIPT"
		script_enabled
		script_logs
		script_saveoff
		script_save
		script_sync
		script_saveon
	fi
}

script_install() {
	echo "Installation"
	echo ""
	echo "Required packages that need to be installed on the server:"
	echo ""
	echo "java"
	echo "screen"
	echo "postfix (optional/for the email feature)"
	echo "zip (optional but required if using the email feature)"
	echo ""
	echo "If these packages aren't installed, terminate this script with CTRL+C and install them."
	echo ""
	echo "The installation will enable linger for the user specified (allows user services to be ran on boot)."
	echo "It will also enable the services needed to run the game server by your specifications."
	echo ""
	echo "List of files that are going to be generated on the system:"
	echo ""
	echo "/home/$USER/.config/systemd/user/$SERVICE_NAME-mkdir-tmpfs.service - Service to generate the folder structure once the RamDisk is started (only executes if RamDisk enabled)."
	echo "/home/$USER/.config/systemd/user/$SERVICE_NAME-tmpfs.service - Server service file for use with a RamDisk (only executes if RamDisk enabled)."
	echo "/home/$USER/.config/systemd/user/$SERVICE_NAME.service - Server service file for normal hdd/ssd use."
	echo "/home/$USER/.config/systemd/user/$SERVICE_NAME-timer-1.timer - Timer for scheduled command execution of $SERVICE_NAME-timer-1.service"
	echo "/home/$USER/.config/systemd/user/$SERVICE_NAME-timer-1.service - Executes scheduled script functions: save, sync, backup and update."
	echo "/home/$USER/.config/systemd/user/$SERVICE_NAME-timer-2.timer - Timer for scheduled command execution of $SERVICE_NAME-timer-2.service"
	echo "/home/$USER/.config/systemd/user/$SERVICE_NAME-timer-2.service - Executes scheduled script functions: save, sync and update."
	echo "/home/$USER/.config/systemd/user/$SERVICE_NAME-timer-3.timer - Timer for scheduled command execution of $SERVICE_NAME-timer-4.service"
	echo "/home/$USER/.config/systemd/user/$SERVICE_NAME-timer-3.service - Executes scheduled update checks for this script"
	echo "/home/$USER/.config/systemd/user/$SERVICE_NAME-send-email.service - If email notifications enabled, send email if server crashed 3 times in 5 minutes."
	echo "/home/$USER/.config/systemd/user/$SERVICE_NAME-serversync.service - Minecraft server sync service"
	echo "$SCRIPT_DIR/$SERVICE_NAME-update.bash - Update script for automatic updates from github."
	echo "$SCRIPT_DIR/$SERVICE_NAME-config.conf - Stores steam username and password. Also stores tmpfs/ramdisk setting."
	echo "$SCRIPT_DIR/$SERVICE_NAME-screen.conf - Screen configuration to enable logging."
	echo ""
	read -p "Press any key to continue" -n 1 -s -r
	echo ""
	read -p "Enter password for user $USER: " USER_PASS
	echo ""
	read -p "Enable RamDisk (y/n): " TMPFS
	echo ""
	
	sudo useradd -m -g users -s /bin/bash $USER
	echo -en "$USER_PASS\n$USER_PASS\n" | sudo passwd $USER
	
	if [[ "$TMPFS" =~ ^([yY][eE][sS]|[yY])$ ]]; then
		TMPFS_ENABLE="1"
		read -p "Do you already have a ramdisk mounted at /mnt/tmpfs? (y/n): " TMPFS_PRESENT
		if [[ "$TMPFS_PRESENT" =~ ^([nN][oO]|[nN])$ ]]; then
			read -p "Ramdisk size (Minimum of 6GB for a single server, 12GB for two and so on): " TMPFS_SIZE
			echo "Installing ramdisk configuration"
			cat >> /etc/fstab <<- EOF
			
			# /mnt/tmpfs
			tmpfs				   /mnt/tmpfs		tmpfs		   rw,size=$TMPFS_SIZE,gid=users,mode=0777	0 0
			EOF
		fi
	fi
		
	echo ""
	read -p "Enable automatic updates for the script from github? (y/n): " SCRIPT_UPDATE_ENABLE
		
	echo ""
	read -p "Enable email notifications (y/n): " POSTFIX_ENABLE
	if [[ "$POSTFIX_ENABLE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
		echo ""
		read -p "Enter the relay host (example: smtp.gmail.com): " POSTFIX_RELAY_HOST
		echo ""
		read -p "Enter the relay host port (example: 587): " POSTFIX_RELAY_HOST_PORT
		echo ""
		read -p "Enter your email address for the server (example: example@gmail.com): " POSTFIX_SENDER
		echo ""
		read -p "Enter your password for $POSTFIX_SENDER : " POSTFIX_SENDER_PSW
		echo ""
		read -p "Enter the email that will recieve the notifications (example: example2@gmail.com): " POSTFIX_RECIPIENT
		echo ""
		read -p "Email notifications for crashes? (y/n): " POSTFIX_CRASH_ENABLE
			if [[ "$POSTFIX_CRASH_ENABLE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
				POSTFIX_CRASH="1"
			fi
		cat >> /etc/postfix/main.cf <<- EOF
		relayhost = [$POSTFIX_RELAY_HOST]:$POSTFIX_RELAY_HOST_PORT
		smtp_sasl_auth_enable = yes
		smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
		smtp_sasl_security_options = noanonymous
		smtp_tls_CApath = /etc/ssl/certs
		smtpd_tls_CApath = /etc/ssl/certs
		smtp_use_tls = yes
		EOF

		cat > /etc/postfix/sasl_passwd <<- EOF
		[$POSTFIX_RELAY_HOST]:$POSTFIX_RELAY_HOST_PORT    $POSTFIX_SENDER:$POSTFIX_SENDER_PSW
		EOF
	
		sudo chmod 400 /etc/postfix/sasl_passwd
		sudo postmap /etc/postfix/sasl_passwd
		sudo systemctl enable postfix
	elif [[ "$POSTFIX_ENABLE" =~ ^([nN][oO]|[nN])$ ]]; then
		POSTFIX_SENDER="none"
		POSTFIX_RECIPIENT="none"
		POSTFIX_CRASH="0"
	fi
	
	echo "Enabling linger"
	sudo mkdir -p /var/lib/systemd/linger/
	sudo touch /var/lib/systemd/linger/$USER
	sudo mkdir -p /home/$USER/.config/systemd/user
	
	echo "Installing bash profile"
	cat > /home/$USER/.bash_profile <<- 'EOF'
	#
	# ~/.bash_profile
	#
	
	[[ -f ~/.bashrc ]] && . ~/.bashrc
	
	export XDG_RUNTIME_DIR="/run/user/$UID"
	export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"
	EOF
	
	echo "Installing service files"
	script_install_services
	
	sudo chown -R $USER:users /home/$USER
	
	echo "Enabling services"
		
	sudo systemctl start user@$(id -u $USER).service
	
	su - $USER -c "systemctl --user enable $SERVICE_NAME-timer-1.timer"
	su - $USER -c "systemctl --user enable $SERVICE_NAME-timer-2.timer"
	
	if [[ "$SCRIPT_UPDATE_ENABLE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
			su - $USER -c "systemctl --user enable $SERVICE_NAME-timer-3.timer"
	fi
	
	if [[ "$TMPFS" =~ ^([yY][eE][sS]|[yY])$ ]]; then
		su - $USER -c "systemctl --user enable $SERVICE_NAME-mkdir-tmpfs.service"
		su - $USER -c "systemctl --user enable $SERVICE_NAME-tmpfs.service"
	elif [[ "$TMPFS" =~ ^([nN][oO]|[nN])$ ]]; then
		su - $USER -c "systemctl --user enable $SERVICE_NAME.service"
	fi
	
	echo "Creating folder structure for server..."
	mkdir -p /home/$USER/{backups,logs,scripts,server,serversync,updates}
	cp "$(readlink -f $0)" $SCRIPT_DIR
	chmod +x $SCRIPT_DIR/$SCRIPT_NAME
	
	echo "Installing screen configuration for server console and logs"
	cat > $SCRIPT_DIR/$SERVICE_NAME-screen.conf <<- EOF
	#
	# This is an example for the global screenrc file.
	# You may want to install this file as /usr/local/etc/screenrc.
	# Check config.h for the exact location.
	#
	# Flaws of termcap and standard settings are done here.
	#
	
	#startup_message off
	
	#defflow on # will force screen to process ^S/^Q
	
	deflogin on
	#autodetach off
	
	vbell on
	vbell_msg "   Wuff  ----  Wuff!!  "
	
	# all termcap entries are now duplicated as terminfo entries.
	# only difference should be the slightly modified syntax, and check for
	# terminfo entries, that are already corected in the database.
	# 
	# G0 	we have a SEMI-GRAPHICS-CHARACTER-MODE
	# WS	this sequence resizes our window.
	# cs    this sequence changes the scrollregion
	# hs@	we have no hardware statusline. screen will only believe that
	#       there is a hardware status line if hs,ts,fs,ds are all set.
	# ts    to statusline
	# fs    from statusline
	# ds    delete statusline
	# al    add one line
	# AL    add multiple lines
	# dl    delete one line
	# DL    delete multiple lines
	# ic    insert one char (space)
	# IC    insert multiple chars
	# nx    terminal uses xon/xoff
	
	termcap  facit|vt100|xterm LP:G0
	terminfo facit|vt100|xterm LP:G0
	
	#the vt100 description does not mention "dl". *sigh*
	termcap  vt100 dl=5\E[M
	terminfo vt100 dl=5\E[M
	
	#facit's "al" / "dl"  are buggy if the current / last line
	#contain attributes...
	termcap  facit al=\E[L\E[K:AL@:dl@:DL@:cs=\E[%i%d;%dr:ic@
	terminfo facit al=\E[L\E[K:AL@:dl@:DL@:cs=\E[%i%p1%d;%p2%dr:ic@
	
	#make sun termcap/info better
	termcap  sun 'up=^K:AL=\E[%dL:DL=\E[%dM:UP=\E[%dA:DO=\E[%dB:LE=\E[%dD:RI=\E[%dC:IC=\E[%d@:WS=1000\E[8;%d;%dt'
	terminfo sun 'up=^K:AL=\E[%p1%dL:DL=\E[%p1%dM:UP=\E[%p1%dA:DO=\E[%p1%dB:LE=\E[%p1%dD:RI=\E[%p1%dC:IC=\E[%p1%d@:WS=\E[8;%p1%d;%p2%dt$<1000>'
	
	#xterm understands both im/ic and doesn't have a status line.
	#Note: Do not specify im and ic in the real termcap/info file as
	#some programs (e.g. vi) will (no,no, may (jw)) not work anymore.
	termcap  xterm|fptwist hs@:cs=\E[%i%d;%dr:im=\E[4h:ei=\E[4l
	terminfo xterm|fptwist hs@:cs=\E[%i%p1%d;%p2%dr:im=\E[4h:ei=\E[4l
	
	# Long time I had this in my private screenrc file. But many people
	# seem to want it (jw):
	# we do not want the width to change to 80 characters on startup:
	# on suns, /etc/termcap has :is=\E[r\E[m\E[2J\E[H\E[?7h\E[?1;3;4;6l:
	termcap xterm 'is=\E[r\E[m\E[2J\E[H\E[?7h\E[?1;4;6l'
	terminfo xterm 'is=\E[r\E[m\E[2J\E[H\E[?7h\E[?1;4;6l'
	
	#
	# Do not use xterms alternate window buffer. 
	# This one would not add lines to the scrollback buffer.
	termcap xterm|xterms|xs ti=\E7\E[?47l
	terminfo xterm|xterms|xs ti=\E7\E[?47l
	
	#make hp700 termcap/info better
	termcap  hp700 'Z0=\E[?3h:Z1=\E[?3l:hs:ts=\E[62"p\E[0$~\E[2$~\E[1$}:fs=\E[0}\E[61"p:ds=\E[62"p\E[1$~\E[61"p:ic@'
	terminfo hp700 'Z0=\E[?3h:Z1=\E[?3l:hs:ts=\E[62"p\E[0$~\E[2$~\E[1$}:fs=\E[0}\E[61"p:ds=\E[62"p\E[1$~\E[61"p:ic@'
	
	#wyse-75-42 must have defflow control (xo = "terminal uses xon/xoff")
	#(nowadays: nx = padding doesn't work, have to use xon/off)
	#essential to have it here, as this is a slow terminal.
	termcap wy75-42 nx:xo:Z0=\E[?3h\E[31h:Z1=\E[?3l\E[31h
	terminfo wy75-42 nx:xo:Z0=\E[?3h\E[31h:Z1=\E[?3l\E[31h
	
	#remove some stupid / dangerous key bindings
	bind ^k
	#bind L
	bind ^\
	#make them better
	bind \\ quit
	bind K kill
	bind I login on
	bind O login off
	bind } history
	
	scrollback 1000
	logfile $LOG_TMP
	logfile flush 0
	deflog on
	EOF
	
	echo "Installing update script"
	script_install_update_script
	
	touch $SCRIPT_DIR/$SERVICE_NAME-config.conf
	echo 'tmpfs_enable='"$TMPFS_ENABLE" >> $SCRIPT_DIR/$SERVICE_NAME-config.conf
	echo 'email_sender='"$POSTFIX_SENDER" >> $SCRIPT_DIR/$SERVICE_NAME-config.conf
	echo 'email_recipient='"$POSTFIX_RECIPIENT" >> $SCRIPT_DIR/$SERVICE_NAME-config.conf
	echo 'email_crash='"$POSTFIX_CRASH" >> $SCRIPT_DIR/$SERVICE_NAME-config.conf
	
	sudo chown -R $USER:users /home/$USER/{backups,logs,scripts,server,serversync,updates}
	
	echo "Installation complete"
	echo ""
	echo "You can login to your the $USER account with <sudo -i -u $USER> from your primary account or root account."
	echo "The script was automaticly copied to the scripts folder located at $SCRIPT_DIR"
	echo "For any settings you'll want to change, edit the $SCRIPT_DIR/$SERVICE_NAME-config.conf file."
	echo ""
}

#Do not allow for another instance of this script to run to prevent data loss
if [[ $(pidof -o %PPID -x $0) -gt "0" ]]; then
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] Another instance of this script is already running. Exiting to prevent data loss."
	exit 0
fi

case "$1" in
	-help)
		echo -e "${CYAN}Time: $(date +"%Y-%m-%d %H:%M:%S") ${NC}"
		echo -e "${CYAN}$NAME server script by 7thCore${NC}"
		echo ""
		echo -e "${LIGHTRED}Before doing anything edit the script and input your steam username and password for the auto update feature to work.${NC}"
		echo -e "${LIGHTRED}The variables for it are located at the very top of the script.${NC}"
		echo -e "${LIGHTRED}Also if you have Steam Guard on your mobile phone activated, disable it because steamcmd always asks for the${NC}"
		echo -e "${LIGHTRED}two factor authentication code and breaks the auto update feature. Use Steam Guard via email.${NC}"
		echo ""
		echo -e "${GREEN}start ${RED}- ${GREEN}Start the server${NC}"
		echo -e "${GREEN}stop ${RED}- ${GREEN}Stop the server${NC}"
		echo -e "${GREEN}restart ${RED}- ${GREEN}Restart the server${NC}"
		echo -e "${GREEN}autorestart ${RED}- ${GREEN}Automaticly restart the server if it's not running${NC}"
		echo -e "${GREEN}save ${RED}- ${GREEN}Issue the save command to the server${NC}"
		echo -e "${GREEN}sync ${RED}- ${GREEN}Sync from tmpfs to hdd/ssd${NC}"
		echo -e "${GREEN}backup ${RED}- ${GREEN}Backup files, if server running or not.${NC}"
		echo -e "${GREEN}autobackup ${RED}- ${GREEN}Automaticly backup files when server running${NC}"
		echo -e "${GREEN}deloldbackup ${RED}- ${GREEN}Delete old backups${NC}"
		echo -e "${GREEN}rebuild_services ${RED}- ${GREEN}Reinstalls the systemd services from the script. Usefull if any service updates occoured.${NC}"
		echo -e "${GREEN}rebuild_update_script ${RED}- ${GREEN}Reinstalls the update script that keeps the primary script up-to-date from github.${NC}"
		echo -e "${GREEN}update ${RED}- ${GREEN}Update the server, if the server is running it wil save it, shut it down, update it and restart it.${NC}"
		echo -e "${GREEN}status ${RED}- ${GREEN}Display status of server${NC}"
		echo ""
		echo -e "${LIGHTRED}If this is your first time running the script:${NC}"
		echo -e "${LIGHTRED}Use the -install argument (run only this command as root) and follow the instructions${NC}"
		echo ""
		echo -e "${LIGHTRED}After that reboot the server and the game should start on it's own on boot."
		echo ""
		echo -e "${LIGHTRED}Example usage: ./$SCRIPT_NAME -start${NC}"
		echo ""
		echo -e "${CYAN}Have a nice day!${NC}"
		;;
	-start)
		script_start
		;;
	-stop)
		script_stop
		;;
	-restart)
		script_restart
		;;
	-saveon)
		script_saveon
		;;
	-saveoff)
		script_saveoff
		;;
	-save)
		script_save
		;;
	-cleardrops)
		script_cleardrops
		;;
	-sync)
		script_sync
		;;
	-backup)
		script_backup
		;;
	-autobackup)
		script_autobackup
		;;
	-deloldbackup)
		script_deloldbackup
		;;
	-status)
		script_status
		;;
	-send_crash_email)
		script_send_crash_email
		;;
	-install)
		script_install
		;;
	-rebuild_services)
		script_install_services
		;;
	-rebuild_update_script)
		script_install_update_script
		;;
	-timer_one)
		script_timer_one
		;;
	-timer_two)
		script_timer_two
		;;
	*)
	echo "Usage: $0 {start|stop|restart|saveon|saveoff|save|cleardrops|sync|backup|autobackup|deloldbackup|rebuild_services|rebuild_update_script|update|status|install}"
	exit 1
	;;
esac

exit 0


#if [[ "$(systemctl --user is-active $SERVICE)" != "active" ]]; then

