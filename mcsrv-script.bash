#!/bin/bash

#Minecraft server script by 7thCore
#If you do not know what any of these settings are you are better off leaving them alone. One thing might brake the other if you fiddle around with it.
export VERSION="202001312016"

#Basics
export NAME="McSrv" #Name of the tmux session
if [ "$EUID" -ne "0" ]; then #Check if script executed as root and asign the username for the installation process, otherwise use the executing user
	USER="$(whoami)"
else
	if [[ "-install" == "$1" ]] || [[ "-install_packages" == "$1" ]]; then
		echo "WARNING: Installation mode"
		read -p "Please enter username (leave empty for minecraft):" USER #Enter desired username that will be used when creating the new user
		USER=${USER:=minecraft} #If no username was given, use default
	else
		echo "Error: This script, once installed, is meant to be used by the user it created and should not under any circumstances be used with sudo or by the root user for the $1 function. Only -install and -install_packages work with sudo/root. Log in to your created user (default: minecraft) with sudo -i -u minecraft and execute your script without root from the coresponding scripts folder."
		exit 1
	fi
fi

#Server configuration
SERVICE_NAME="mcsrv" #Name of the service files, script and script log
SRV_DIR="/home/$USER/server" #Location of the server located on your hdd/ssd
SCRIPT_NAME="$SERVICE_NAME-script.bash" #Script name
SCRIPT_DIR="/home/$USER/scripts" #Location of this script
SERVER_SYNC_DIR="/home/$USER/serversync"

if [ -f "$SCRIPT_DIR/$SERVICE_NAME-config.conf" ] ; then
	#Email configuration
	EMAIL_SENDER=$(cat $SCRIPT_DIR/$SERVICE_NAME-config.conf | grep email_sender | cut -d = -f2) #Send emails from this address
	EMAIL_RECIPIENT=$(cat $SCRIPT_DIR/$SERVICE_NAME-config.conf | grep email_recipient | cut -d = -f2) #Send emails to this address
	EMAIL_UPDATE_SCRIPT=$(cat $SCRIPT_DIR/$SERVICE_NAME-config.conf | grep email_update_script | cut -d = -f2) #Send notification when the script updates
	EMAIL_START=$(cat $SCRIPT_DIR/$SERVICE_NAME-config.conf | grep email_start | cut -d = -f2) #Send emails when the server starts up
	EMAIL_STOP=$(cat $SCRIPT_DIR/$SERVICE_NAME-config.conf | grep email_stop | cut -d = -f2) #Send emails when the server shuts down
	EMAIL_CRASH=$(cat $SCRIPT_DIR/$SERVICE_NAME-config.conf | grep email_crash | cut -d = -f2) #Send emails when the server crashes

	#Discord configuration
	DISCORD_UPDATE_SCRIPT=$(cat $SCRIPT_DIR/$SERVICE_NAME-config.conf | grep discord_update_script | cut -d = -f2) #Send notification when the script updates
	DISCORD_START=$(cat $SCRIPT_DIR/$SERVICE_NAME-config.conf | grep discord_start | cut -d = -f2) #Send notifications when the server starts
	DISCORD_STOP=$(cat $SCRIPT_DIR/$SERVICE_NAME-config.conf | grep discord_stop | cut -d = -f2) #Send notifications when the server stops
	DISCORD_CRASH=$(cat $SCRIPT_DIR/$SERVICE_NAME-config.conf | grep discord_crash | cut -d = -f2) #Send notifications when the server crashes

	#Ramdisk configuration
	TMPFS_ENABLE=$(cat $SCRIPT_DIR/$SERVICE_NAME-config.conf | grep tmpfs_enable | cut -d = -f2) #Get configuration for tmpfs

	#Backup configuration
	BCKP_DELOLD=$(cat $SCRIPT_DIR/$SERVICE_NAME-config.conf | grep bckp_delold | cut -d = -f2) #Delete old backups.

	#Log configuration
	LOG_DELOLD=$(cat $SCRIPT_DIR/$SERVICE_NAME-config.conf | grep log_delold | cut -d = -f2) #Delete old logs.

	#Script updates from github
	SCRIPT_UPDATES_GITHUB=$(cat $SCRIPT_DIR/$SERVICE_NAME-config.conf | grep script_updates | cut -d = -f2) #Get configuration for script updates.
	
	#ServerSync
	SERVER_SYNC=$(cat $SCRIPT_DIR/$SERVICE_NAME-config.conf | grep serversync | cut -d = -f2) #Get configuration for script updates.
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

#Log configuration
export LOG_DIR="/home/$USER/logs/$(date +"%Y")/$(date +"%m")/$(date +"%d")"
export LOG_SCRIPT="$LOG_DIR/$SERVICE_NAME-script.log" #Script log
export LOG_TMP="/tmp/$USER-$SERVICE_NAME-tmux.log"

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
	find $LOG_DIR/* -mtime +$LOG_DELOLD -exec rm {} \;
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

#Disable all script services
script_disable_services() {
	if [[ "$(systemctl --user show -p UnitFileState --value $SERVICE_NAME-mkdir-tmpfs.service)" == "enabled" ]]; then
		systemctl --user disable $SERVICE_NAME-mkdir-tmpfs.service
	fi
	if [[ "$(systemctl --user show -p UnitFileState --value $SERVICE_NAME-tmpfs.service)" == "enabled" ]]; then
		systemctl --user disable $SERVICE_NAME-tmpfs.service
	fi
	if [[ "$(systemctl --user show -p UnitFileState --value $SERVICE_NAME.service)" == "enabled" ]]; then
		systemctl --user disable $SERVICE_NAME.service
	fi
	if [[ "$(systemctl --user show -p UnitFileState --value $SERVICE_NAME-timer-1.timer)" == "enabled" ]]; then
		systemctl --user disable $SERVICE_NAME-timer-1.timer
	fi
	if [[ "$(systemctl --user show -p UnitFileState --value $SERVICE_NAME-timer-2.timer)" == "enabled" ]]; then
		systemctl --user disable $SERVICE_NAME-timer-2.timer
	fi
	if [[ "$(systemctl --user show -p UnitFileState --value $SERVICE_NAME-serversync.service)" == "enabled" ]]; then
		systemctl --user disable $SERVICE_NAME-timer-2.timer
	fi
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Disable services) Services successfully disabled." | tee -a "$LOG_SCRIPT"
}

#Disables all script services, available to the user
script_disable_services_manual() {
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Disable services) WARNING: This will disable all script services. The server will be disabled." | tee -a "$LOG_SCRIPT"
	read -p "Are you sure you want to disable all services? (y/n): " DISABLE_SCRIPT_SERVICES
	if [[ "$DISABLE_SCRIPT_SERVICES" =~ ^([yY][eE][sS]|[yY])$ ]]; then
		script_disable_services
	elif [[ "$DISABLE_SCRIPT_SERVICES" =~ ^([nN][oO]|[nN])$ ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Disable services) Disable services canceled." | tee -a "$LOG_SCRIPT"
	fi
}

# Enable script services by reading the configuration file
script_enable_services() {
	if [[ "$TMPFS_ENABLE" == "1" ]]; then
		if [[ "$(systemctl --user show -p UnitFileState --value $SERVICE_NAME-mkdir-tmpfs.service)" == "disabled" ]]; then
			systemctl --user enable $SERVICE_NAME-mkdir-tmpfs.service
		fi
		if [[ "$(systemctl --user show -p UnitFileState --value $SERVICE_NAME-tmpfs.service)" == "disabled" ]]; then
			systemctl --user enable $SERVICE_NAME-tmpfs.service
		fi
	else
		if [[ "$(systemctl --user show -p UnitFileState --value $SERVICE_NAME.service)" == "disabled" ]]; then
			systemctl --user enable $SERVICE_NAME.service
		fi
	fi
	if [[ "$(systemctl --user show -p UnitFileState --value $SERVICE_NAME-timer-1.timer)" == "disabled" ]]; then
		systemctl --user enable $SERVICE_NAME-timer-1.timer
	fi
	if [[ "$(systemctl --user show -p UnitFileState --value $SERVICE_NAME-timer-2.timer)" == "disabled" ]]; then
		systemctl --user enable $SERVICE_NAME-timer-2.timer
	fi
	if [[ "$(systemctl --user show -p UnitFileState --value $SERVICE_NAME-serversync.service)" == "disabled" ]]; then
		if [[ "$SERVER_SYNC" == "1" ]]; then
			systemctl --user enable $SERVICE_NAME-timer-2.timer
		fi
	fi
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Enable services) Services successfully Enabled." | tee -a "$LOG_SCRIPT"
}

# Enable script services by reading the configuration file, available to the user
script_enable_services_manual() {
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Enable services) This will enable all script services. The server will be enabled." | tee -a "$LOG_SCRIPT"
	read -p "Are you sure you want to disable all services? (y/n): " ENABLE_SCRIPT_SERVICES
	if [[ "$ENABLE_SCRIPT_SERVICES" =~ ^([yY][eE][sS]|[yY])$ ]]; then
		script_enable_services
	elif [[ "$ENABLE_SCRIPT_SERVICES" =~ ^([nN][oO]|[nN])$ ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Enable services) Enable services canceled." | tee -a "$LOG_SCRIPT"
	fi
}

#Disables all script services an re-enables them by reading the configuration file
script_reload_services() {
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Reload services) This will reload all script services." | tee -a "$LOG_SCRIPT"
	read -p "Are you sure you want to reload all services? (y/n): " RELOAD_SCRIPT_SERVICES
	if [[ "$RELOAD_SCRIPT_SERVICES" =~ ^([yY][eE][sS]|[yY])$ ]]; then
		script_disable_services
		systemctl --user daemon-reload
		script_enable_services
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Reload services) Reload services complete." | tee -a "$LOG_SCRIPT"
	elif [[ "$RELOAD_SCRIPT_SERVICES" =~ ^([nN][oO]|[nN])$ ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Reload services) Reload services canceled." | tee -a "$LOG_SCRIPT"
	fi
}

#Systemd service sends notification if notifications for start enabled
script_send_notification_start_initialized() {
	if [[ "$EMAIL_START" == "1" ]]; then
		mail -r "$EMAIL_SENDER ($NAME-$USER)" -s "Notification: Server startup" $EMAIL_RECIPIENT <<- EOF
		Server startup was initiated at $(date +"%d.%m.%Y %H:%M:%S")
		EOF
	fi
	if [[ "$DISCORD_START" == "1" ]]; then
		while IFS="" read -r DISCORD_WEBHOOK || [ -n "$DISCORD_WEBHOOK" ]; do
			curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server startup was initialized.\"}" "$DISCORD_WEBHOOK"
		done < $SCRIPT_DIR/discord_webhooks.txt
	fi
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server startup initialized." | tee -a "$LOG_SCRIPT"
}

#Systemd service sends notification if notifications for start enabled
script_send_notification_start_complete() {
	if [[ "$EMAIL_START" == "1" ]]; then
		mail -r "$EMAIL_SENDER ($NAME-$USER)" -s "Notification: Server startup" $EMAIL_RECIPIENT <<- EOF
		Server startup was completed at $(date +"%d.%m.%Y %H:%M:%S")
		EOF
	fi
	if [[ "$DISCORD_START" == "1" ]]; then
		while IFS="" read -r DISCORD_WEBHOOK || [ -n "$DISCORD_WEBHOOK" ]; do
			curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server startup complete.\"}" "$DISCORD_WEBHOOK"
		done < $SCRIPT_DIR/discord_webhooks.txt
	fi
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server startup complete." | tee -a "$LOG_SCRIPT"
}

#Systemd service sends notification if notifications for stop enabled
script_send_notification_stop_initialized() {
	if [[ "$EMAIL_STOP" == "1" ]]; then
		mail -r "$EMAIL_SENDER ($NAME-$USER)" -s "Notification: Server shutdown" $EMAIL_RECIPIENT <<- EOF
		Server shutdown was initiated at $(date +"%d.%m.%Y %H:%M:%S")
		EOF
	fi
	if [[ "$DISCORD_STOP" == "1" ]]; then
		while IFS="" read -r DISCORD_WEBHOOK || [ -n "$DISCORD_WEBHOOK" ]; do
			curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Stop) Server shutdown in progress.\"}" "$DISCORD_WEBHOOK"
		done < $SCRIPT_DIR/discord_webhooks.txt
	fi
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Stop) Server shutdown in progress." | tee -a "$LOG_SCRIPT"
}

#Systemd service sends notification if notifications for stop enabled
script_send_notification_stop_complete() {
	if [[ "$EMAIL_STOP" == "1" ]]; then
		mail -r "$EMAIL_SENDER ($NAME-$USER)" -s "Notification: Server shutdown" $EMAIL_RECIPIENT <<- EOF
		Server shutdown was complete at $(date +"%d.%m.%Y %H:%M:%S")
		EOF
	fi
	if [[ "$DISCORD_STOP" == "1" ]]; then
		while IFS="" read -r DISCORD_WEBHOOK || [ -n "$DISCORD_WEBHOOK" ]; do
			curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Stop) Server shutdown complete\"}" "$DISCORD_WEBHOOK"
		done < $SCRIPT_DIR/discord_webhooks.txt
	fi
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Stop) Server shutdown complete." | tee -a "$LOG_SCRIPT"
}

#Systemd service sends email if email notifications for crashes enabled
script_send_notification_crash() {
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
	if [[ "$DISCORD_CRASH" == "1" ]]; then
		while IFS="" read -r DISCORD_WEBHOOK || [ -n "$DISCORD_WEBHOOK" ]; do
			curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"Notification: The server crashed 3 times in the last 5 minutes. Automatic restart is disabled and the server is inactive. Contact an admin for further information. Time of crash: $(date +"%d.%m.%Y %H:%M:%S")\"}" "$DISCORD_WEBHOOK"
		done < $SCRIPT_DIR/discord_webhooks.txt
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
		( sleep 5 && /usr/bin/tmux -L $USER-tmux.sock send-keys -t $NAME.0 "save-on" ENTER ) &
		timeout $TIMEOUT /bin/bash -c '
		while read line; do
			if [[ "$line" =~ "[Server thread/INFO] [minecraft/DedicatedServer]: Turned on world auto-saving" ]]; then
				echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Save on) Autosaving has been Activated." | tee -a  "$LOG_SCRIPT"
				/usr/bin/tmux -L $USER-tmux.sock send-keys -t $NAME.0 "say Automatic world saving is enabled." ENTER
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
		( sleep 5 && /usr/bin/tmux -L $USER-tmux.sock send-keys -t $NAME.0 "save-off" ENTER ) &
		timeout $TIMEOUT /bin/bash -c '
		while read line; do
			if [[ "$line" =~ "[Server thread/INFO] [minecraft/DedicatedServer]: Turned off world auto-saving" ]]; then
				echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Save off) Autosaving has been deactivated." | tee -a  "$LOG_SCRIPT"
				/usr/bin/tmux -L $USER-tmux.sock send-keys -t $NAME.0 "say Automatic world saving is disabled." ENTER
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
		( sleep 5 && /usr/bin/tmux -L $USER-tmux.sock send-keys -t $NAME.0 "save-all" ENTER ) &
		timeout $TIMEOUT /bin/bash -c '
		while read line; do
			if [[ "$line" =~ "[Server thread/INFO] [minecraft/DedicatedServer]: Saved the world" ]]; then
				echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Save) Save game to disk has been completed." | tee -a  "$LOG_SCRIPT"
				/usr/bin/tmux -L $USER-tmux.sock send-keys -t $NAME.0 "say World save complete." ENTER
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
		/usr/bin/tmux -L $USER-tmux.sock send-keys -t $NAME.0 "say Warning! Clearing all drops in 1 minutes!" ENTER &&
		sleep 30 &&
		/usr/bin/tmux -L $USER-tmux.sock send-keys -t $NAME.0 "say Warning! Clearing all drops in 30 seconds!" ENTER &&
		sleep 15 &&
		/usr/bin/tmux -L $USER-tmux.sock send-keys -t $NAME.0 "say Warning! Clearing all drops in 15 seconds!" ENTER &&
		sleep 5 &&
		/usr/bin/tmux -L $USER-tmux.sock send-keys -t $NAME.0 "say Warning! Clearing all drops in 10 seconds!" ENTER &&
		sleep 5 &&
		/usr/bin/tmux -L $USER-tmux.sock send-keys -t $NAME.0 "say Warning! Clearing all drops in 5 seconds!" ENTER &&
		sleep 1 &&
		/usr/bin/tmux -L $USER-tmux.sock send-keys -t $NAME.0 "say Warning! Clearing all drops in 4 seconds!" ENTER &&
		sleep 1 &&
		/usr/bin/tmux -L $USER-tmux.sock send-keys -t $NAME.0 "say Warning! Clearing all drops in 3 seconds!" ENTER &&
		sleep 1 &&
		/usr/bin/tmux -L $USER-tmux.sock send-keys -t $NAME.0 "say Warning! Clearing all drops in 2 seconds!" ENTER &&
		sleep 1 &&
		/usr/bin/tmux -L $USER-tmux.sock send-keys -t $NAME.0 "say Warning! Clearing all drops in 1 seconds!" ENTER &&
		sleep 1 &&
		/usr/bin/tmux -L $USER-tmux.sock send-keys -t $NAME.0 "say Clearing drops." ENTER &&
		/usr/bin/tmux -L $USER-tmux.sock send-keys -t $NAME.0 "/kill @e[type=item]" ENTER &&
		sleep 1 ) &
		timeout $TIMEOUT /bin/bash -c '
		while read line; do
			if [[ "$line" =~ "/kill @e[type=item]" ]]; then
				echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Clear Drops) Clearing drops complete." | tee -a  "$LOG_SCRIPT"
				/usr/bin/tmux -L $USER-tmux.sock send-keys -t $NAME.0 "say Clearing drops complete." ENTER
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
			/usr/bin/tmux -L $USER-tmux.sock send-keys -t $NAME.0 "say File sync complete." ENTER
		fi
	elif [[ "$TMPFS_ENABLE" == "0" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Sync) Server does not have tmpfs enabled." | tee -a  "$LOG_SCRIPT"
	fi
}

#Start the server
script_start() {
	if [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "inactive" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server start initialized." | tee -a "$LOG_SCRIPT"
		systemctl --user start $SERVICE
		sleep 1
		while [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "activating" ]]; do
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server is activating. Please wait..." | tee -a "$LOG_SCRIPT"
			sleep 1
		done
		if [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "active" ]]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server has been successfully activated." | tee -a "$LOG_SCRIPT"
			sleep 1
		elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "failed" ]]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server failed to activate. See systemctl --user status $SERVICE for details." | tee -a "$LOG_SCRIPT"
			sleep 1
		fi
	elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "active" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server is already running." | tee -a "$LOG_SCRIPT"
		sleep 1
	elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "failed" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server failed to activate. See systemctl --user status $SERVICE for details." | tee -a "$LOG_SCRIPT"
		read -p "Do you still want to start the server?: (y/n)" FORCE_START
		if [[ "$FORCE_START" =~ ^([yY][eE][sS]|[yY])$ ]]; then
			systemctl --user start $SERVICE
			sleep 1
			while [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "activating" ]]; do
				echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server is activating. Please wait..." | tee -a "$LOG_SCRIPT"
				sleep 1
			done
			if [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "active" ]]; then
				echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server has been successfully activated." | tee -a "$LOG_SCRIPT"
				sleep 1
			elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "failed" ]]; then
				echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server failed to activate. See systemctl --user status $SERVICE for details." | tee -a "$LOG_SCRIPT"
				sleep 1
			fi
		fi
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
		/usr/bin/tmux -L $USER-tmux.sock send-keys -t $NAME.0 "say Server restarting in 15 seconds." ENTER
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
	find $BCKP_DIR/* -mtime +$BCKP_DELOLD -exec rm {} \;
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
		/usr/bin/tmux -L $USER-tmux.sock send-keys -t $NAME.0 "say Server backup in progress." ENTER
		sleep 1
		script_backup
		sleep 1
		script_deloldbackup
		/usr/bin/tmux -L $USER-tmux.sock send-keys -t $NAME.0 "say Server backup complete." ENTER

	fi
}

#Delete server save
script_delete_save() {
	if [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" != "active" ]] && [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" != "activating" ]] && [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" != "deactivating" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Delete save) WARNING! This will delete the server's save game." | tee -a "$LOG_SCRIPT"
		read -p "Are you sure you want to delete the server's save game? (y/n): " DELETE_SERVER_SAVE
		if [[ "$DELETE_SERVER_SAVE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
			read -p "Do you also want to delete the server.properties? (y/n): " DELETE_SERVER_SSKJSON
			if [[ "$DELETE_SERVER_SSKJSON" =~ ^([yY][eE][sS]|[yY])$ ]]; then
				if [[ "$TMPFS_ENABLE" == "1" ]]; then
					rm -rf $TMPFS_DIR
				fi
				rm -rf "$(find $SRV_DIR -type f -name 'level.dat' -printf '%h\n')"
				echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Delete save) Deletion of save files server.properties file complete." | tee -a "$LOG_SCRIPT"
			elif [[ "$DELETE_SERVER_SSKJSON" =~ ^([nN][oO]|[nN])$ ]]; then
				if [[ "$TMPFS_ENABLE" == "1" ]]; then
					rm -rf $TMPFS_DIR
				fi
				cd "$SRV_DIR/"
				rm -rf $(ls | grep -v server.properties)
				echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Delete save) Deletion of save files complete. The server.properties file untouched." | tee -a "$LOG_SCRIPT"
			fi
		elif [[ "$DELETE_SERVER_SAVE" =~ ^([nN][oO]|[nN])$ ]]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Delete save) Save deletion canceled." | tee -a "$LOG_SCRIPT"
		fi
	elif [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "active" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Clear save) The server is running. Aborting..." | tee -a "$LOG_SCRIPT"
	fi
}

#Install aliases in .bashrc
script_install_alias(){
	if [ "$EUID" -ne "0" ]; then #Check if script executed as root and asign the username for the installation process, otherwise use the executing user
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Install .bashrc aliases) Installation of aliases in .bashrc commencing. Waiting on user configuration." | tee -a "$LOG_SCRIPT"
		read -p "Are you sure you want to install bash aliases into .bashrc? (y/n): " INSTALL_BASHRC_ALIAS
		if [[ "$INSTALL_BASHRC_ALIAS" =~ ^([yY][eE][sS]|[yY])$ ]]; then
			INSTALL_BASHRC_ALIAS_STATE="1"
		elif [[ "$INSTALL_BASHRC_ALIAS" =~ ^([nN][oO]|[nN])$ ]]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Install .bashrc aliases) Installation of aliases in .bashrc aborted." | tee -a "$LOG_SCRIPT"
			INSTALL_BASHRC_ALIAS_STATE="0"
		fi
	else
		INSTALL_BASHRC_ALIAS_STATE="1"
	fi
	
	if [[ "$INSTALL_BASHRC_ALIAS_STATE" == "1" ]]; then
		cat >> /home/$USER/.bashrc <<- EOF
			alias $SERVICE_NAME-server='tmux -L $USER-tmux.sock attach -t $NAME'
			alias $SERVICE_NAME-serversync='tmux -L $USER-serversync-tmux.sock attach -t ServerSync'
		EOF
	fi
	
	if [ "$EUID" -ne "0" ]; then
		if [[ "$INSTALL_BASHRC_ALIAS_STATE" == "1" ]]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Install .bashrc aliases) Installation of aliases in .bashrc complete. Re-log for the changes to take effect." | tee -a "$LOG_SCRIPT"
			echo "Aliases:"
			echo "$SERVICE_NAME-server = Attaches to the server console."
			echo "$SERVICE_NAME-serversync = Attaches to the ServerSync console."
		fi
	fi
}

#Install or reinstall tmux configuration
script_install_tmux_config() {
	if [ "$EUID" -ne "0" ]; then #Check if script executed as root and asign the username for the installation process, otherwise use the executing user
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Reinstall tmux configuration) Tmux configuration reinstallation commencing. Waiting on user configuration." | tee -a "$LOG_SCRIPT"
		read -p "Are you sure you want to reinstall the tmux configuration? (y/n): " REINSTALL_TMUX_CONFIG
		if [[ "$REINSTALL_TMUX_CONFIG" =~ ^([yY][eE][sS]|[yY])$ ]]; then
			INSTALL_TMUX_CONFIG_STATE="1"
		elif [[ "$REINSTALL_TMUX_CONFIG" =~ ^([nN][oO]|[nN])$ ]]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Reinstall tmux configuration) Tmux configuration reinstallation aborted." | tee -a "$LOG_SCRIPT"
			INSTALL_TMUX_CONFIG_STATE="0"
		fi
	else
		INSTALL_TMUX_CONFIG_STATE="1"
	fi
	
	if [[ "$INSTALL_TMUX_CONFIG_STATE" == "1" ]]; then
		if [ -f "$SCRIPT_DIR/$SERVICE_NAME-tmux.conf" ]; then
			rm $SCRIPT_DIR/$SERVICE_NAME-tmux.conf
		fi
		
		cat > $SCRIPT_DIR/$SERVICE_NAME-tmux.conf <<- EOF
		#Tmux configuration
		set -g activity-action other
		set -g allow-rename off
		set -g assume-paste-time 1
		set -g base-index 0
		set -g bell-action any
		set -g default-command "${SHELL}"
		set -g default-terminal "tmux-256color" 
		set -g default-shell "/bin/bash"
		set -g default-size "132x42"
		set -g destroy-unattached off
		set -g detach-on-destroy on
		set -g display-panes-active-colour red
		set -g display-panes-colour blue
		set -g display-panes-time 1000
		set -g display-time 3000
		set -g history-limit 10000
		set -g key-table "root"
		set -g lock-after-time 0
		set -g lock-command "lock -np"
		set -g message-command-style fg=yellow,bg=black
		set -g message-style fg=black,bg=yellow
		set -g mouse on
		#set -g prefix C-b
		set -g prefix2 None
		set -g renumber-windows off
		set -g repeat-time 500
		set -g set-titles off
		set -g set-titles-string "#S:#I:#W - \"#T\" #{session_alerts}"
		set -g silence-action other
		set -g status on
		set -g status-bg green
		set -g status-fg black
		set -g status-format[0] "#[align=left range=left #{status-left-style}]#{T;=/#{status-left-length}:status-left}#[norange default]#[list=on align=#{status-justify}]#[list=left-marker]<#[list=right-marker]>#[list=on]#{W:#[range=window|#{window_index} #{window-status-style}#{?#{&&:#{window_last_flag},#{!=:#{window-status-last-style},default}}, #{window-status-last-style},}#{?#{&&:#{window_bell_flag},#{!=:#{window-status-bell-style},default}}, #{window-status-bell-style},#{?#{&&:#{||:#{window_activity_flag},#{window_silence_flag}},#{!=:#{window-status-activity-style},default}}, #{window-status-activity-style},}}]#{T:window-status-format}#[norange default]#{?window_end_flag,,#{window-status-separator}},#[range=window|#{window_index} list=focus #{?#{!=:#{window-status-current-style},default},#{window-status-current-style},#{window-status-style}}#{?#{&&:#{window_last_flag},#{!=:#{window-status-last-style},default}}, #{window-status-last-style},}#{?#{&&:#{window_bell_flag},#{!=:#{window-status-bell-style},default}}, #{window-status-bell-style},#{?#{&&:#{||:#{window_activity_flag},#{window_silence_flag}},#{!=:#{window-status-activity-style},default}}, #{window-status-activity-style},}}]#{T:window-status-current-format}#[norange list=on default]#{?window_end_flag,,#{window-status-separator}}}#[nolist align=right range=right #{status-right-style}]#{T;=/#{status-right-length}:status-right}#[norange default]"
		set -g status-format[1] "#[align=centre]#{P:#{?pane_active,#[reverse],}#{pane_index}[#{pane_width}x#{pane_height}]#[default] }"
		set -g status-interval 15
		set -g status-justify left
		set -g status-keys emacs
		set -g status-left "[#S] "
		set -g status-left-length 10
		set -g status-left-style default
		set -g status-position bottom
		set -g status-right "#{?window_bigger,[#{window_offset_x}#,#{window_offset_y}] ,}\"#{=21:pane_title}\" %H:%M %d-%b-%y"
		set -g status-right-length 40
		set -g status-right-style default
		set -g status-style fg=black,bg=green
		set -g update-environment[0] "DISPLAY"
		set -g update-environment[1] "KRB5CCNAME"
		set -g update-environment[2] "SSH_ASKPASS"
		set -g update-environment[3] "SSH_AUTH_SOCK"
		set -g update-environment[4] "SSH_AGENT_PID"
		set -g update-environment[5] "SSH_CONNECTION"
		set -g update-environment[6] "WINDOWID"
		set -g update-environment[7] "XAUTHORITY"
		set -g visual-activity off
		set -g visual-bell off
		set -g visual-silence off
		set -g word-separators " -_@"

		#Change prefix key from ctrl+b to ctrl+a
		unbind C-b
		set -g prefix C-a
		bind C-a send-prefix

		#Bind C-a r to reload the config file
		bind-key r source-file $SCRIPT_DIR/$SERVICE_NAME-tmux.conf \; display-message "Config reloaded!"

		set-hook -g session-created 'resize-window -y 24 -x 10000'
		set-hook -g session-created "pipe-pane -o 'tee >> $LOG_TMP'"
		set-hook -g client-attached 'resize-window -y 24 -x 10000'
		set-hook -g client-detached 'resize-window -y 24 -x 10000'
		set-hook -g client-resized 'resize-window -y 24 -x 10000'

		#Default key bindings (only here for info)
		#Ctrl-b l (Move to the previously selected window)
		#Ctrl-b w (List all windows / window numbers)
		#Ctrl-b <window number> (Move to the specified window number, the default bindings are from 0 – 9)
		#Ctrl-b q  (Show pane numbers, when the numbers show up type the key to goto that pane)

		#Ctrl-b f <window name> (Search for window name)
		#Ctrl-b w (Select from interactive list of windows)

		#Copy/ scroll mode
		#Ctrl-b [ (in copy mode you can navigate the buffer including scrolling the history. Use vi or emacs-style key bindings in copy mode. The default is emacs. To exit copy mode use one of the following keybindings: vi q emacs Esc)
		EOF
	fi
	
	if [ "$EUID" -ne "0" ]; then
		if [[ "$INSTALL_TMUX_CONFIG_STATE" == "1" ]]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Reinstall tmux configuration) Tmux configuration reinstallation complete. Restart your server for changes to take affect." | tee -a "$LOG_SCRIPT"
		fi
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
		OnFailure=$SERVICE_NAME-send-notification.service
		
		[Service]
		Type=forking
		WorkingDirectory=$TMPFS_DIR
		ExecStartPre=$SCRIPT_DIR/$SCRIPT_NAME -send_notification_start_initialized
		ExecStartPre=/usr/bin/rsync -av --info=progress2 $SRV_DIR/ $TMPFS_DIR
		EOF
		echo "ExecStart=/usr/bin/tmux -f $SCRIPT_DIR/$SERVICE_NAME-tmux.conf -L %u-tmux.sock new-session -d -s $NAME 'java -server -XX:+UseG1GC -Xmx6G -Xms1G -Dsun.rmi.dgc.server.gcInterval=2147483646 -XX:+UnlockExperimentalVMOptions -XX:G1NewSizePercent=20 -XX:G1ReservePercent=20 -XX:MaxGCPauseMillis=50 -XX:G1HeapRegionSize=32M -Dfml.ignorePatchDiscrepancies=true -Dfml.ignoreInvalidMinecraftCertificates=true -jar"' $(ls -v '$TMPFS_DIR' | grep -i "forge-.*\.jar" | head -n 1) nogui'\' >> /home/$USER/.config/systemd/user/$SERVICE_NAME-tmpfs.service
		cat >> /home/$USER/.config/systemd/user/$SERVICE_NAME-tmpfs.service <<- EOF
		ExecStartPost=$SCRIPT_DIR/$SCRIPT_NAME -send_notification_start_complete
		ExecStop=$SCRIPT_DIR/$SCRIPT_NAME -send_notification_stop_initialized
		ExecStop=/usr/bin/tmux -L %u-tmux.sock send-keys -t $NAME.0 'say SERVER SHUTTING DOWN IN 10!' ENTER
		ExecStop=/usr/bin/sleep 5
		ExecStop=/usr/bin/tmux -L %u-tmux.sock send-keys -t $NAME.0 'SERVER SHUTTING DOWN IN 5!' ENTER
		ExecStop=/usr/bin/sleep 5
		ExecStop=/usr/bin/tmux -L %u-tmux.sock send-keys -t $NAME.0 'say SERVER SHUTTING DOWN NOW!' ENTER
		ExecStop=/usr/bin/tmux -L %u-tmux.sock send-keys -t $NAME.0 'save-all' ENTER
		ExecStop=/usr/bin/tmux -L %u-tmux.sock send-keys -t $NAME.0 'stop' ENTER
		ExecStop=/usr/bin/sleep 10
		ExecStop=/usr/bin/rsync -av --info=progress2 $TMPFS_DIR/ $SRV_DIR
		ExecStopPost=$SCRIPT_DIR/$SCRIPT_NAME -send_notification_stop_complete
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
		OnFailure=$SERVICE_NAME-send-notification.service
		
		[Service]
		Type=forking
		WorkingDirectory=$SRV_DIR
		ExecStartPre=$SCRIPT_DIR/$SCRIPT_NAME -send_notification_start_initialized
		EOF
		echo "ExecStart=/usr/bin/tmux -f $SCRIPT_DIR/$SERVICE_NAME-tmux.conf -L %u-tmux.sock new-session -d -s $NAME 'java -server -XX:+UseG1GC -Xmx6G -Xms1G -Dsun.rmi.dgc.server.gcInterval=2147483646 -XX:+UnlockExperimentalVMOptions -XX:G1NewSizePercent=20 -XX:G1ReservePercent=20 -XX:MaxGCPauseMillis=50 -XX:G1HeapRegionSize=32M -Dfml.ignorePatchDiscrepancies=true -Dfml.ignoreInvalidMinecraftCertificates=true -jar"' $(ls -v '$SRV_DIR' | grep -i "forge-.*\.jar" | head -n 1) nogui'\' >> /home/$USER/.config/systemd/user/$SERVICE_NAME.service
		cat >> /home/$USER/.config/systemd/user/$SERVICE_NAME.service <<- EOF
		ExecStartPost=$SCRIPT_DIR/$SCRIPT_NAME -send_notification_start_complete
		ExecStop=$SCRIPT_DIR/$SCRIPT_NAME -send_notification_stop_initialized
		ExecStop=/usr/bin/tmux -L %u-tmux.sock send-keys -t $NAME.0 'say SERVER SHUTTING DOWN IN 10!' ENTER
		ExecStop=/usr/bin/sleep 5
		ExecStop=/usr/bin/tmux -L %u-tmux.sock send-keys -t $NAME.0 'SERVER SHUTTING DOWN IN 5!' ENTER
		ExecStop=/usr/bin/sleep 5
		ExecStop=/usr/bin/tmux -L %u-tmux.sock send-keys -t $NAME.0 'say SERVER SHUTTING DOWN NOW!' ENTER
		ExecStop=/usr/bin/tmux -L %u-tmux.sock send-keys -t $NAME.0 'save-all' ENTER
		ExecStop=/usr/bin/tmux -L %u-tmux.sock send-keys -t $NAME.0 'stop' ENTER
		ExecStop=/usr/bin/sleep 10
		ExecStopPost=$SCRIPT_DIR/$SCRIPT_NAME -send_notification_stop_complete
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
		
		cat > /home/$USER/.config/systemd/user/$SERVICE_NAME-serversync.service <<- EOF
		[Unit]
		Description=Minecraft Server Sync Service
		After=network.target

		[Service]
		Type=forking
		WorkingDirectory=$SERVER_SYNC_DIR
		EOF
		echo "ExecStart=/usr/bin/tmux -f $SCRIPT_DIR/$SERVICE_NAME-tmux.conf -L %u-serversync-tmux.sock new-session -d -s ServerSync 'java -jar "'$(ls -v '$SERVER_SYNC_DIR' | grep -i "serversync" | head -n 1) server'\' >> /home/$USER/.config/systemd/user/$SERVICE_NAME-serversync.service
		cat >> /home/$USER/.config/systemd/user/$SERVICE_NAME-serversync.service <<- EOF
		ExecStop=/usr/bin/tmux -L %u-serversync-tmux.sock kill-session -t ServerSync

		Restart=on-failure
		RestartSec=60

		[Install]
		WantedBy=default.target
		EOF
		
		cat > /home/$USER/.config/systemd/user/$SERVICE_NAME-send-notification.service <<- EOF
		[Unit]
		Description=$NAME Script Send Email notification Service
		
		[Service]
		Type=oneshot
		ExecStart=$SCRIPT_DIR/$SCRIPT_NAME -send_notification_crash
		EOF
	fi
	
	if [ "$EUID" -ne "0" ]; then
		if [[ "$INSTALL_SYSTEMD_SERVICES_STATE" == "1" ]]; then
			systemctl --user daemon-reload
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Reinstall systemd services) Systemd services reinstallation complete." | tee -a "$LOG_SCRIPT"
		fi
	fi
}

#Check github for script updates and update if newer version available
script_update_github() {
	if [[ "$SCRIPT_UPDATES_GITHUB" == "1" ]]; then
		GITHUB_VERSION=$(curl -s https://raw.githubusercontent.com/7thCore/$SERVICE_NAME-script/master/$SERVICE_NAME-script.bash | grep "^export VERSION=" | sed 's/"//g' | cut -d = -f2)
		if [ "$GITHUB_VERSION" -gt "$VERSION" ]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Script update) Script update detected." | tee -a $LOG_SCRIPT
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Script update) Installed:$VERSION, Available:$GITHUB_VERSION" | tee -a $LOG_SCRIPT
			
			if [[ "$DISCORD_UPDATE_SCRIPT" == "1" ]]; then
				while IFS="" read -r DISCORD_WEBHOOK || [ -n "$DISCORD_WEBHOOK" ]; do
					curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Script update) Update detected. Installing update.\"}" "$DISCORD_WEBHOOK"
				done < $SCRIPT_DIR/discord_webhooks.txt
			fi
			
			git clone https://github.com/7thCore/$SERVICE_NAME-script /$UPDATE_DIR/$SERVICE_NAME-script
			rm $SCRIPT_DIR/$SERVICE_NAME-script.bash
			cp --remove-destination $UPDATE_DIR/$SERVICE_NAME-script/$SERVICE_NAME-script.bash $SCRIPT_DIR/$SERVICE_NAME-script.bash
			chmod +x $SCRIPT_DIR/$SERVICE_NAME-script.bash
			rm -rf $UPDATE_DIR/$SERVICE_NAME-script
			
			if [[ "$EMAIL_UPDATE_SCRIPT" == "1" ]]; then
				mail -r "$EMAIL_SENDER ($NAME-$USER)" -s "Notification: Script Update" $EMAIL_RECIPIENT <<- EOF
				Script was updated. Please check the update notes if there are any additional steps to take.
				Previous version: $VERSION
				Current version: $GITHUB_VERSION
				EOF
			fi
			
			if [[ "$DISCORD_UPDATE_SCRIPT" == "1" ]]; then
				while IFS="" read -r DISCORD_WEBHOOK || [ -n "$DISCORD_WEBHOOK" ]; do
					curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Script update) Update complete. Installed version: $GITHUB_VERSION.\"}" "$DISCORD_WEBHOOK"
				done < $SCRIPT_DIR/discord_webhooks.txt
			fi
		else
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Script update) No new script updates detected." | tee -a $LOG_SCRIPT
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Script update) Installed:$VERSION, Available:$VERSION" | tee -a $LOG_SCRIPT
		fi
	fi
}

#Get latest script from github no matter what the version
script_update_github_force() {
	GITHUB_VERSION=$(curl -s https://raw.githubusercontent.com/7thCore/$SERVICE_NAME-script/master/$SERVICE_NAME-script.bash | grep "^export VERSION=" | sed 's/"//g' | cut -d = -f2)
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Script update) Forcing script update." | tee -a $LOG_SCRIPT
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Script update) Installed:$VERSION, Available:$GITHUB_VERSION" | tee -a $LOG_SCRIPT
	git clone https://github.com/7thCore/$SERVICE_NAME-script /$UPDATE_DIR/$SERVICE_NAME-script
	rm $SCRIPT_DIR/$SERVICE_NAME-script.bash
	cp --remove-destination $UPDATE_DIR/$SERVICE_NAME-script/$SERVICE_NAME-script.bash $SCRIPT_DIR/$SERVICE_NAME-script.bash
	chmod +x $SCRIPT_DIR/$SERVICE_NAME-script.bash
	rm -rf $UPDATE_DIR/$SERVICE_NAME-script
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Script update) Forced script update complete." | tee -a $LOG_SCRIPT
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
		script_update_github
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
		script_update_github
	fi
}

script_install_packages() {
	if [ -f "/etc/os-release" ]; then
		#Get distro name
		DISTRO=$(cat /etc/os-release | grep "^ID=" | cut -d = -f2)
		
		#Check for current distro
		if [[ "$DISTRO" == "arch" ]]; then
			#Arch distro
			
			#Add arch linux multilib repository
			echo "[multilib]" >> /mnt/etc/pacman.conf
			echo "Include = /etc/pacman.d/mirrorlist" >> /mnt/etc/pacman.conf
			
			#Install packages and enable services
			sudo pacman -Syu --noconfirm rsync unzip p7zip wget curl tmux postfix zip jre8-openjdk jq
		elif [[ "$DISTRO" == "ubuntu" ]]; then
			#Ubuntu distro
			
			#Get codename
			UBUNTU_CODENAME=$(cat /etc/os-release | grep "^UBUNTU_CODENAME=" | cut -d = -f2)
			
			#Install packages and enable services
			sudo apt install rsync unzip p7zip wget curl tmux zip postfix jq
		fi
		echo "Package installation complete."
	else
		echo "os-release file not found. Is this distro supported?"
		echo "This script currently supports Arch Linux and Ubuntu 19.10"
		exit 1
	fi
}

script_install() {
	echo "Installation"
	echo ""
	echo "Required packages that need to be installed on the server:"
	echo ""
	echo "java"
	echo "rsync"
	echo "tmux"
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
	echo "/home/$USER/.config/systemd/user/$SERVICE_NAME-send-notification.service - If email notifications enabled, send email if server crashed 3 times in 5 minutes."
	echo "/home/$USER/.config/systemd/user/$SERVICE_NAME-serversync.service - Minecraft server sync service"
	echo "$SCRIPT_DIR/$SERVICE_NAME-script.bash - This script."
	echo "$SCRIPT_DIR/$SERVICE_NAME-config.conf - Stores settings for the script."
	echo "$SCRIPT_DIR/$SERVICE_NAME-screen.conf - Tmux configuration to enable logging."
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
			tmpfs				   /mnt/tmpfs		tmpfs		   rw,size=$TMPFS_SIZE,gid=$(cat /etc/group | grep users | grep -o '[[:digit:]]*'),mode=0777	0 0
			EOF
		fi
	fi
	
	echo ""
	echo "WARNING: script updates from github may include malicious code to steal any info the script uses to work, like email accound and password."
	echo "Not saying i'm that kind of person that would do that but:"
	echo "IF YOU DON'T TRUST ME, LEAVE THIS OFF FOR SECURITY REASONS!"
	read -p "Enable automatic updates for the script from github? (y/n): " SCRIPT_UPDATE_CONFIG
	SCRIPT_UPDATE_CONFIG=${SCRIPT_UPDATE_CONFIG:=n}
	if [[ "$SCRIPT_UPDATE_CONFIG" =~ ^([yY][eE][sS]|[yY])$ ]]; then
		SCRIPT_UPDATE_ENABLED="1"
	else
		SCRIPT_UPDATE_ENABLED="0"
	fi
	
	read -p "Install ServerSync? (y/n): " SERVERSYNC_SETUP
	if [[ "$SERVERSYNC_SETUP" =~ ^([yY][eE][sS]|[yY])$ ]]; then
		SERVERSYNC_INSTALL="1"
	else
		SERVERSYNC_INSTALL="0"
	fi
	
	echo ""
	read -p "Enable email notifications (y/n): " POSTFIX_ENABLE
	if [[ "$POSTFIX_ENABLE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
		read -p "Is postfix already configured? (y/n): " POSTFIX_CONFIGURED
		echo ""
		read -p "Enter your email address for the server (example: example@gmail.com): " POSTFIX_SENDER
		echo ""
		if [[ "$POSTFIX_CONFIGURED" =~ ^([nN][oO]|[nN])$ ]]; then
			read -p "Enter your password for $POSTFIX_SENDER : " POSTFIX_SENDER_PSW
		fi
		echo ""
		read -p "Enter the email that will recieve the notifications (example: example2@gmail.com): " POSTFIX_RECIPIENT
		echo ""
		echo ""
		read -p "Email notifications for script updates? (y/n): " POSTFIX_UPDATE_SCRIPT_ENABLE
			if [[ "$POSTFIX_UPDATE_SCRIPT_ENABLE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
				POSTFIX_UPDATE_SCRIPT="1"
			fi
		read -p "Email notifications for server startup? (WARNING: this can be anoying) (y/n): " POSTFIX_CRASH_ENABLE
			if [[ "$POSTFIX_CRASH_ENABLE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
				POSTFIX_START="1"
			fi
		echo ""
		read -p "Email notifications for server shutdown? (WARNING: this can be anoying) (y/n): " POSTFIX_CRASH_ENABLE
			if [[ "$POSTFIX_CRASH_ENABLE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
				POSTFIX_STOP="1"
			fi
		echo ""
		read -p "Email notifications for crashes? (y/n): " POSTFIX_CRASH_ENABLE
			if [[ "$POSTFIX_CRASH_ENABLE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
				POSTFIX_CRASH="1"
			fi
		if [[ "$POSTFIX_CONFIGURED" =~ ^([nN][oO]|[nN])$ ]]; then
			echo ""
			read -p "Enter the relay host (example: smtp.gmail.com): " POSTFIX_RELAY_HOST
			echo ""
			read -p "Enter the relay host port (example: 587): " POSTFIX_RELAY_HOST_PORT
			echo ""
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
		fi
	elif [[ "$POSTFIX_ENABLE" =~ ^([nN][oO]|[nN])$ ]]; then
		POSTFIX_SENDER="none"
		POSTFIX_RECIPIENT="none"
		POSTFIX_START="0"
		POSTFIX_STOP="0"
		POSTFIX_CRASH="0"
	fi
	
	echo ""
	read -p "Enable discord notifications (y/n): " DISCORD_ENABLE
	if [[ "$DISCORD_ENABLE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
		echo ""
		echo "You are able to add multiple webhooks for the script to use in the discord_webhooks.txt file located in the scripts folder."
		echo "EACH ONE HAS TO BE IN IT'S OWN LINE!"
		echo ""
		read -p "Enter your first webhook for the server: " DISCORD_WEBHOOK
		echo ""
		read -p "Discord notifications for game updates? (y/n): " DISCORD_UPDATE_SCRIPT_ENABLE
			if [[ "$DISCORD_UPDATE_SCRIPT_ENABLE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
				DISCORD_UPDATE_SCRIPT="1"
			fi
		echo ""
		read -p "Discord notifications for server startup? (y/n): " DISCORD_START_ENABLE
			if [[ "$DISCORD_START_ENABLE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
				DISCORD_START="1"
			fi
		echo ""
		read -p "Discord notifications for server shutdown? (y/n): " DISCORD_STOP_ENABLE
			if [[ "$DISCORD_STOP_ENABLE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
				DISCORD_STOP="1"
			fi
		echo ""
		read -p "Discord notifications for crashes? (y/n): " DISCORD_CRASH_ENABLE
			if [[ "$DISCORD_CRASH_ENABLE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
				DISCORD_CRASH="1"
			fi
	elif [[ "$DISCORD_ENABLE" =~ ^([nN][oO]|[nN])$ ]]; then
		DISCORD_START="0"
		DISCORD_STOP="0"
		DISCORD_CRASH="0"
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
	
	if [[ "$TMPFS" =~ ^([yY][eE][sS]|[yY])$ ]]; then
		su - $USER -c "systemctl --user enable $SERVICE_NAME-mkdir-tmpfs.service"
		su - $USER -c "systemctl --user enable $SERVICE_NAME-tmpfs.service"
	elif [[ "$TMPFS" =~ ^([nN][oO]|[nN])$ ]]; then
		su - $USER -c "systemctl --user enable $SERVICE_NAME.service"
	fi
	
	echo "Creating folder structure for server..."
	mkdir -p /home/$USER/{backups,logs,scripts,server,updates}
	cp "$(readlink -f $0)" $SCRIPT_DIR
	chmod +x $SCRIPT_DIR/$SCRIPT_NAME
	
	echo "Installing tmux configuration for server console and logs"
	script_install_tmux_config
	
	if [[ "$SERVERSYNC_INSTALL" == "1" ]]; then
		echo "Downloading and installing ServerSync from github."
		mkdir -p /home/$USER/serversync
		curl -s https://api.github.com/repos/official-antistasi-community/A3-Antistasi/releases/latest | jq -r ".assets[] | select(.name | contains(\"jar\")) | .browser_download_url" | wget -i -
		cp $PWD/serversync*.jar /home/$USER/serversync/
		sudo chown -R $USER:users /home/$USER/serversync
		su - $USER -c "systemctl --user enable $SERVICE_NAME-serversync.service"
	fi
	
	touch $SCRIPT_DIR/$SERVICE_NAME-config.conf
	echo 'tmpfs_enable='"$TMPFS_ENABLE" >> $SCRIPT_DIR/$SERVICE_NAME-config.conf
	echo 'email_sender='"$POSTFIX_SENDER" >> $SCRIPT_DIR/$SERVICE_NAME-config.conf
	echo 'email_recipient='"$POSTFIX_RECIPIENT" >> $SCRIPT_DIR/$SERVICE_NAME-config.conf
	echo 'email_update_script='"$POSTFIX_UPDATE_SCRIPT" >> $SCRIPT_DIR/$SERVICE_NAME-config.conf
	echo 'email_start='"$POSTFIX_START" >> $SCRIPT_DIR/$SERVICE_NAME-config.conf
	echo 'email_stop='"$POSTFIX_STOP" >> $SCRIPT_DIR/$SERVICE_NAME-config.conf
	echo 'email_crash='"$POSTFIX_CRASH" >> $SCRIPT_DIR/$SERVICE_NAME-config.conf
	echo 'discord_update_script='"$DISCORD_UPDATE_SCRIPT" >> $SCRIPT_DIR/$SERVICE_NAME-config.conf
	echo 'discord_start='"$DISCORD_START" >> $SCRIPT_DIR/$SERVICE_NAME-config.conf
	echo 'discord_stop='"$DISCORD_STOP" >> $SCRIPT_DIR/$SERVICE_NAME-config.conf
	echo 'discord_crash='"$DISCORD_CRASH" >> $SCRIPT_DIR/$SERVICE_NAME-config.conf
	echo 'script_updates='"$SCRIPT_UPDATE_ENABLED" >> $SCRIPT_DIR/$SERVICE_NAME-config.conf
	echo 'bckp_delold=14' >> $SCRIPT_DIR/$SERVICE_NAME-config.conf
	echo 'log_delold=7' >> $SCRIPT_DIR/$SERVICE_NAME-config.conf
	echo 'serversync='"$SERVERSYNC_INSTALL" >> $SCRIPT_DIR/$SERVICE_NAME-config.conf
	
	sudo chown -R $USER:users /home/$USER/{backups,logs,scripts,server,updates}
	
	echo "Installation complete"
	echo ""
	echo "You can login to your the $USER account with <sudo -i -u $USER> from your primary account or root account."
	echo "The script was automaticly copied to the scripts folder located at $SCRIPT_DIR"
	echo "For any settings you'll want to change, edit the $SCRIPT_DIR/$SERVICE_NAME-config.conf file."
	echo ""
}

#Do not allow for another instance of this script to run to prevent data loss
if [[ "-send_notification_start_initialized" != "$1" ]] && [[ "-send_notification_start_complete" != "$1" ]] && [[ "-send_notification_stop_initialized" != "$1" ]] && [[ "-send_notification_stop_complete" != "$1" ]] && [[ "-send_notification_crash" != "$1" ]]; then
	SCRIPT_PID_CHECK=$(basename -- "$0")
	if pidof -x "$SCRIPT_PID_CHECK" -o $$ > /dev/null; then
		echo "An another instance of this script is already running, please clear all the sessions of this script before starting a new session"
		exit 1
	fi
fi

if [ "$EUID" -ne "0" ] && [ -f "$SCRIPT_DIR/$SERVICE_NAME-config.conf" ]; then #Check if script executed as root, if not generate missing config fields
	CONFIG_FIELDS="tmpfs_enable,email_sender,email_recipient,email_update_script,email_start,email_stop,email_crash,discord_update_script,discord_start,discord_stop,discord_crash,script_updates,bckp_delold,log_delold,serversync"
	IFS=","
	for CONFIG_FIELD in $CONFIG_FIELDS; do
		if ! grep -q $CONFIG_FIELD $SCRIPT_DIR/$SERVICE_NAME-config.conf; then
			if [[ "$CONFIG_FIELD" == "bckp_delold" ]]; then
				echo "$CONFIG_FIELD=14" >> $SCRIPT_DIR/$SERVICE_NAME-config.conf
			elif [[ "$CONFIG_FIELD" == "log_delold" ]]; then
				echo "$CONFIG_FIELD=7" >> $SCRIPT_DIR/$SERVICE_NAME-config.conf
			else
				echo "$CONFIG_FIELD=0" >> $SCRIPT_DIR/$SERVICE_NAME-config.conf
			fi
		fi
	done
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
		echo -e "${GREEN}-start ${RED}- ${GREEN}Start the server${NC}"
		echo -e "${GREEN}-stop ${RED}- ${GREEN}Stop the server${NC}"
		echo -e "${GREEN}-restart ${RED}- ${GREEN}Restart the server${NC}"
		echo -e "${GREEN}-autorestart ${RED}- ${GREEN}Automaticly restart the server if it's not running${NC}"
		echo -e "${GREEN}-save ${RED}- ${GREEN}Issue the save command to the server${NC}"
		echo -e "${GREEN}-sync ${RED}- ${GREEN}Sync from tmpfs to hdd/ssd${NC}"
		echo -e "${GREEN}-backup ${RED}- ${GREEN}Backup files, if server running or not${NC}"
		echo -e "${GREEN}-autobackup ${RED}- ${GREEN}Automaticly backup files when server running${NC}"
		echo -e "${GREEN}-deloldbackup ${RED}- ${GREEN}Delete old backups${NC}"
		echo -e "${GREEN}-install_aliases ${RED}- ${GREEN}Installs .bashrc aliases for easy access to the server tmux session${NC}"
		echo -e "${GREEN}-rebuild_tmux_config ${RED}- ${GREEN}Reinstalls the tmux configuration file from the script. Usefull if any tmux configuration updates occoured${NC}"
		echo -e "${GREEN}-rebuild_services ${RED}- ${GREEN}Reinstalls the systemd services from the script. Usefull if any service updates occoured${NC}"
		echo -e "${GREEN}-disable_services ${RED}- ${GREEN}Disables all services. The server and the script will not start up on boot anymore${NC}"
		echo -e "${GREEN}-enable_services ${RED}- ${GREEN}Enables all services dependant on the configuration file of the script${NC}"
		echo -e "${GREEN}-reload_services ${RED}- ${GREEN}Reloads all services, dependant on the configuration file${NC}"
		#echo -e "${GREEN}update ${RED}- ${GREEN}Update the server, if the server is running it wil save it, shut it down, update it and restart it.${NC}"
		echo -e "${GREEN}-update_script ${RED}- ${GREEN}Check github for script updates and update if newer version available${NC}"
		echo -e "${GREEN}-update_script_force ${RED}- ${GREEN}Get latest script from github and install it no matter what the version${NC}"
		echo -e "${GREEN}-status ${RED}- ${GREEN}Display status of server${NC}"
		echo -e "${GREEN}-install ${RED}- ${GREEN}Installs all the needed files for the script to run, the wine prefix and the game${NC}"
		echo -e "${GREEN}-install_packages ${RED}- ${GREEN}Installs all the needed packages (Supports only Arch linux & Ubuntu 19.10 and onward)${NC}"
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
	-update_script)
		script_update_github
		;;
	-update_script_force)
		script_update_github_force
		;;
	-status)
		script_status
		;;
	-send_notification_start_initialized)
		script_send_notification_start_initialized
		;;
	-send_notification_start_complete)
		script_send_notification_start_complete
		;;
	-send_notification_stop_initialized)
		script_send_notification_stop_initialized
		;;
	-send_notification_stop_complete)
		script_send_notification_stop_complete
		;;
	-send_notification_crash)
		script_script_send_notification_crash
		;;
	-install_aliases)
		script_install_alias
		;;
	-rebuild_tmux_config)
		script_install_tmux_config
		;;
	-install)
		script_install
		;;
	-rebuild_services)
		script_install_services
		;;
	-disable_services)
		script_disable_services_manual
		;;
	-enable_services)
		script_enable_services_manual
		;;
	-reload_services)
		script_reload_services
		;;
	-timer_one)
		script_timer_one
		;;
	-timer_two)
		script_timer_two
		;;
	*)
	echo "Usage: $0 {start|stop|restart|saveon|saveoff|save|cleardrops|sync|backup|autobackup|deloldbackup|install_aliases|rebuild_tmux_config|rebuild_services|disable_services|enable_services|reload_services|update_script|update_script_force|status|install}"
	exit 1
	;;
esac

exit 0


#if [[ "$(systemctl --user is-active $SERVICE)" != "active" ]]; then

