#!/bin/bash

#Minecraft server script by 7thCore
#If you do not know what any of these settings are you are better off leaving them alone. One thing might brake the other if you fiddle around with it.
export VERSION="202012090456"

#Basics
export NAME="McSrv" #Name of the tmux session
if [ "$EUID" -ne "0" ]; then #Check if script executed as root and asign the username for the installation process, otherwise use the executing user
	USER="$(whoami)"
else
	if [[ "-install" == "$1" ]]; then
		echo "WARNING: Installation mode"
		read -p "Please enter username (leave empty for minecraft):" USER #Enter desired username that will be used when creating the new user
		USER=${USER:=minecraft} #If no username was given, use default
	elif [[ "-install_packages" == "$1" ]]; then
		echo "Commencing installation of required packages."
	elif [[ "-help" == "$1" ]]; then
		echo "Displaying help message"
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
UPDATE_DIR="/home/$USER/updates" #Location of update information for the script's automatic update feature
SERVER_SYNC_DIR="/home/$USER/serversync" #Location of the serversync folder for mod updates

if [ -f "$SCRIPT_DIR/$SERVICE_NAME-config.conf" ] ; then
	#Game type (vanilla, spigot, forge)
	GAME_TYPE=$(cat $SCRIPT_DIR/$SERVICE_NAME-config.conf | grep type= | cut -d = -f2) #Send emails from this address
	
	#Email configuration
	EMAIL_SENDER=$(cat $SCRIPT_DIR/$SERVICE_NAME-config.conf | grep email_sender= | cut -d = -f2) #Send emails from this address
	EMAIL_RECIPIENT=$(cat $SCRIPT_DIR/$SERVICE_NAME-config.conf | grep email_recipient= | cut -d = -f2) #Send emails to this address
	EMAIL_UPDATE_SCRIPT=$(cat $SCRIPT_DIR/$SERVICE_NAME-config.conf | grep email_update_script= | cut -d = -f2) #Send notification when the script updates
	EMAIL_START=$(cat $SCRIPT_DIR/$SERVICE_NAME-config.conf | grep email_start= | cut -d = -f2) #Send emails when the server starts up
	EMAIL_STOP=$(cat $SCRIPT_DIR/$SERVICE_NAME-config.conf | grep email_stop= | cut -d = -f2) #Send emails when the server shuts down
	EMAIL_CRASH=$(cat $SCRIPT_DIR/$SERVICE_NAME-config.conf | grep email_crash= | cut -d = -f2) #Send emails when the server crashes

	#Discord configuration
	DISCORD_UPDATE_SCRIPT=$(cat $SCRIPT_DIR/$SERVICE_NAME-config.conf | grep discord_update_script= | cut -d = -f2) #Send notification when the script updates
	DISCORD_START=$(cat $SCRIPT_DIR/$SERVICE_NAME-config.conf | grep discord_start= | cut -d = -f2) #Send notifications when the server starts
	DISCORD_STOP=$(cat $SCRIPT_DIR/$SERVICE_NAME-config.conf | grep discord_stop= | cut -d = -f2) #Send notifications when the server stops
	DISCORD_CRASH=$(cat $SCRIPT_DIR/$SERVICE_NAME-config.conf | grep discord_crash= | cut -d = -f2) #Send notifications when the server crashes

	#Ramdisk configuration
	TMPFS_ENABLE=$(cat $SCRIPT_DIR/$SERVICE_NAME-config.conf | grep tmpfs_enable= | cut -d = -f2) #Get configuration for tmpfs

	#Backup configuration
	BCKP_DELOLD=$(cat $SCRIPT_DIR/$SERVICE_NAME-config.conf | grep bckp_delold= | cut -d = -f2) #Delete old backups.

	#Log configuration
	LOG_DELOLD=$(cat $SCRIPT_DIR/$SERVICE_NAME-config.conf | grep log_delold= | cut -d = -f2) #Delete old logs.

	#Ignore failed startups during update configuration
	UPDATE_IGNORE_FAILED_ACTIVATIONS=$(cat $SCRIPT_DIR/$SERVICE_NAME-config.conf | grep update_ignore_failed_startups= | cut -d = -f2)
	
	#Automatic updates for vanilla minecraft
	GAME_SERVER_UPDATES=$(cat $SCRIPT_DIR/$SERVICE_NAME-config.conf | grep ^updates= | cut -d = -f2) #Get configuration for script updates.
	
	#Script updates from github
	SCRIPT_UPDATES_GITHUB=$(cat $SCRIPT_DIR/$SERVICE_NAME-config.conf | grep script_updates= | cut -d = -f2) #Get configuration for script updates.
	
	#ServerSync
	SERVER_SYNC=$(cat $SCRIPT_DIR/$SERVICE_NAME-config.conf | grep serversync= | cut -d = -f2) #Get configuration for script updates.
else
	if [[ "-install" != "$1" ]] && [[ "-install_packages" != "$1" ]] && [[ "-help" != "$1" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Configuration) Error: The configuration file is missing. Generating missing configuration strings using default values."
	fi
fi

#Ramdisk configuration
TMPFS_DIR="/mnt/tmpfs/$USER" #Locaton of your ramdisk. Note: you have to configure the ramdisk in /etc/fstab before using this.

#TmpFs/hdd variables
if [[ "$TMPFS_ENABLE" == "1" ]]; then
        BCKP_SRC_DIR="$TMPFS_DIR/" #Application data of the tmpfs
		if [[ "$GAME_TYPE" == "1" ]]; then
			SERVICE="$SERVICE_NAME-vanilla-tmpfs.service" #TmpFs vanilla service file name
		elif [[ "$GAME_TYPE" == "2" ]]; then
			SERVICE="$SERVICE_NAME-spigot-tmpfs.service" #TmpFs spigot service file name
		elif [[ "$GAME_TYPE" == "3" ]]; then
			SERVICE="$SERVICE_NAME-forge-tmpfs.service" #TmpFs forge service file name
		fi
else
	    BCKP_SRC_DIR="$SRV_DIR/" #Application data of the hdd/ssd
		if [[ "$GAME_TYPE" == "1" ]]; then
			SERVICE="$SERVICE_NAME-vanilla.service" #Hdd/ssd vanilla service file name
		elif [[ "$GAME_TYPE" == "2" ]]; then
			SERVICE="$SERVICE_NAME-spigot.service" #Hdd/ssd spigot service file name
		elif [[ "$GAME_TYPE" == "3" ]]; then
			SERVICE="$SERVICE_NAME-forge.service" #Hdd/ssd forgeservice file name
		fi
	fi

#Backup configuration
#BCKP_SRC="banned-ips.json banned-players.json ops.json server.properties whitelist.json world server.jar" #What files to backup, * for all
BCKP_SRC="/home/$USER/server/"
BCKP_DIR="/home/$USER/backups" #Location of stored backups
BCKP_DEST="$BCKP_DIR/$(date +"%Y")/$(date +"%m")/$(date +"%d")" #How backups are sorted, by default it's sorted in folders by month and day

#Log configuration
export LOG_DIR="/home/$USER/logs/$(date +"%Y")/$(date +"%m")/$(date +"%d")"
export LOG_DIR_ALL="/home/$USER/logs"
export LOG_SCRIPT="$LOG_DIR/$SERVICE_NAME-script.log" #Script log
export LOG_TMP="/tmp/$USER-$SERVICE_NAME-tmux.log"
export CRASH_DIR="/home/$USER/logs/crashes/$(date +"%Y-%m-%d_%H-%M")"

TIMEOUT=120

#-------Do not edit anything beyond this line-------

#Console collors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
LIGHTRED='\033[1;31m'
NC='\033[0m'

#Generate log folder structure
script_logs() {
	#If there is not a folder for today, create one
	if [ ! -d "$LOG_DIR" ]; then
		mkdir -p $LOG_DIR
	fi
}

#Deletes old files
script_remove_old_files() {
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Remove old files) Beginning removal of old files." | tee -a "$LOG_SCRIPT"
	#Delete old logs
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Remove old files) Removing old script logs: $LOG_DELOLD days old." | tee -a "$LOG_SCRIPT"
	find $LOG_DIR_ALL/* -mtime +$LOG_DELOLD -delete
	#Delete empty folders
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Remove old files) Removing empty script log folders." | tee -a "$LOG_SCRIPT"
	find $LOG_DIR_ALL/ -type d -empty -delete
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Remove old files) Removal of old files complete." | tee -a "$LOG_SCRIPT"
}

#Deletes old logs
script_del_logs() {
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Delete old logs) Deleting old logs: $LOG_DELOLD days old." | tee -a "$LOG_SCRIPT"
	#Delete old logs
	find $LOG_DIR_ALL/* -mtime +$LOG_DELOLD -delete
	#Delete empty folders
	find $LOG_DIR_ALL/ -type d -empty -delete
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Delete old logs) Deleting old logs complete." | tee -a "$LOG_SCRIPT"
}

#Prints out if the server is running
script_status() {
	script_logs
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

#Attaches to the server tmux session
script_attach() {
	tmux -L $USER-tmux.sock attach -t $NAME
}

#Disable all script services
script_disable_services() {
	script_logs
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
	script_logs
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
	script_logs
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
	script_logs
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Enable services) This will enable all script services. The server will be enabled." | tee -a "$LOG_SCRIPT"
	read -p "Are you sure you want to enable all services? (y/n): " ENABLE_SCRIPT_SERVICES
	if [[ "$ENABLE_SCRIPT_SERVICES" =~ ^([yY][eE][sS]|[yY])$ ]]; then
		script_enable_services
	elif [[ "$ENABLE_SCRIPT_SERVICES" =~ ^([nN][oO]|[nN])$ ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Enable services) Enable services canceled." | tee -a "$LOG_SCRIPT"
	fi
}

#Disables all script services an re-enables them by reading the configuration file
script_reload_services() {
	script_logs
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
	script_logs
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
	script_logs
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
	script_logs
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
	script_logs
	if [[ "$EMAIL_STOP" == "1" ]]; then
		mail -r "$EMAIL_SENDER ($NAME-$USER)" -s "Notification: Server shutdown" $EMAIL_RECIPIENT <<- EOF
		Server shutdown was complete at $(date +"%d.%m.%Y %H:%M:%S")
		EOF
	fi
	if [[ "$DISCORD_STOP" == "1" ]]; then
		while IFS="" read -r DISCORD_WEBHOOK || [ -n "$DISCORD_WEBHOOK" ]; do
			curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Stop) Server shutdown complete.\"}" "$DISCORD_WEBHOOK"
		done < $SCRIPT_DIR/discord_webhooks.txt
	fi
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Stop) Server shutdown complete." | tee -a "$LOG_SCRIPT"
}

#Systemd service sends email if email notifications for crashes enabled
script_send_notification_crash() {
	script_logs
	if [ ! -d "$CRASH_DIR" ]; then
		mkdir -p "$CRASH_DIR"
	fi
	
	systemctl --user status $SERVICE > $CRASH_DIR/service_log.txt
	zip -j $CRASH_DIR/service_logs.zip $CRASH_DIR/service_log.txt
	zip -j $CRASH_DIR/script_logs.zip $LOG_SCRIPT
	rm $CRASH_DIR/service_log.txt
	
	if [[ "$EMAIL_CRASH" == "1" ]]; then
		mail -a $CRASH_DIR/service_logs.zip -a $CRASH_DIR/script_logs.zip -a -r "$EMAIL_SENDER ($NAME $USER)" -s "Notification: Crash" $EMAIL_RECIPIENT <<- EOF
		The server crashed 3 times in the last 5 minutes. Automatic restart is disabled and the server is inactive. Please check the logs for more information.
		
		Attachment contents:
		service_logs.zip - Logs from the systemd service
		script_logs.zip - Logs from the script
		
		DO NOT SEND ANY OF THESE TO THE DEVS!
		
		Contact the script developer 7thCore on discord for help regarding any problems the script may have caused.
		EOF
	fi
	
	if [[ "$DISCORD_CRASH" == "1" ]]; then
		while IFS="" read -r DISCORD_WEBHOOK || [ -n "$DISCORD_WEBHOOK" ]; do
			curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Crash) The server crashed 3 times in the last 5 minutes. Automatic restart is disabled and the server is inactive. Please review your logs located in $CRASH_DIR.\"}" "$DISCORD_WEBHOOK"
		done < $SCRIPT_DIR/discord_webhooks.txt
	fi
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Crash) Server crashed. Please review your logs located in $CRASH_DIR." | tee -a "$LOG_SCRIPT"
}

#Enable automatic world saving
script_saveon() {
	script_logs
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
			if [[ "$line" =~ "[Server thread/INFO]:" ]] && [[ "$line" =~ "Automatic saving is now enabled" ]]; then
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
	script_logs
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
			if [[ "$line" =~ "[Server thread/INFO]:" ]] && [[ "$line" =~ "Automatic saving is now disabled" ]]; then
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
	script_logs
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
			if [[ "$line" =~ "[Server thread/INFO]:" ]] && [[ "$line" =~ "Saved the game" ]]; then
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
	script_logs
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
	script_logs
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
	script_logs
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
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server is in failed state. See systemctl --user status $SERVICE for details." | tee -a "$LOG_SCRIPT"
		read -p "Do you still want to start the server? (y/n): " FORCE_START
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

#Start the server ignorring failed states
script_start_ignore_errors() {
	script_logs
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
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Start) Server is in failed state. See systemctl --user status $SERVICE for details." | tee -a "$LOG_SCRIPT"
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
}

#Stop the server
script_stop() {
	script_logs
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
	script_logs
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
	script_logs
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
	script_logs
	#If there is not a folder for today, create one
	if [ ! -d "$BCKP_DEST" ]; then
		mkdir -p $BCKP_DEST
	fi
	#Backup source to destination
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Backup) Backup has been initiated." | tee -a  "$LOG_SCRIPT"
	cd "$BCKP_SRC_DIR"
	tar -cpvzf $BCKP_DEST/$(date +"%Y%m%d%H%M").tar.gz "$BCKP_SRC" #| sed -e "s/^/$(date +"%Y-%m-%d %H:%M:%S") [$NAME] [INFO] (Backup) Compressing: /" | tee -a  "$LOG_SCRIPT"
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Backup) Backup complete." | tee -a  "$LOG_SCRIPT"
}

#Automaticly backs up the server and deletes old backups
script_autobackup() {
	script_logs
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
	script_logs
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

#Check for updates. If there are updates available, shut down the server, update it and restart it.
script_update() {
	script_logs
	if [[ "$GAME_SERVER_UPDATES" == "1" ]]; then
		if [[ "$GAME_TYPE" == "1" ]]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Update) Initializing update check." | tee -a "$LOG_SCRIPT"
			
			if [ ! -f $UPDATE_DIR/installed.version ] ; then
				touch $UPDATE_DIR/installed.version
				echo "0" > $UPDATE_DIR/installed.version
			fi
			
			if [ ! -f $UPDATE_DIR/installed.sha1 ] ; then
				touch $UPDATE_DIR/installed.sha1
				echo "0" > $UPDATE_DIR/installed.sha1
			fi
			
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Update) Connecting to mojang servers." | tee -a "$LOG_SCRIPT"
			
			LATEST_VERSION=$(curl -s "https://launchermeta.mojang.com/mc/game/version_manifest.json" | jq -r '.latest.release')
			JSON_URL=$(curl -s "https://launchermeta.mojang.com/mc/game/version_manifest.json" | jq ".versions[] | select(.id==\"$LATEST_VERSION\") .url" | sed 's/"//g')
			JAR_SHA1=$(curl -s "$JSON_URL" | jq '.downloads.server .sha1' | sed 's/"//g')
			JAR_URL=$(curl -s "$JSON_URL" | jq '.downloads.server .url' | sed 's/"//g')
			
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Update) Received application info data." | tee -a "$LOG_SCRIPT"
			
			INSTALLED_VERSION=$(cat $UPDATE_DIR/installed.version)
			INSTALLED_SHA1=$(cat $UPDATE_DIR/installed.sha1)
			
			if [[ "$JAR_SHA1" != "$INSTALLED_SHA1" ]]; then
				echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Update) New update detected." | tee -a "$LOG_SCRIPT"
				echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Update) Installed: Version: $INSTALLED_VERSION, SHA1: $INSTALLED_SHA1" | tee -a "$LOG_SCRIPT"
				echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Update) Available: Version: $LATEST_VERSION, SHA1: $JAR_SHA1" | tee -a "$LOG_SCRIPT"
				
				if [[ "$DISCORD_UPDATE" == "1" ]]; then
					while IFS="" read -r DISCORD_WEBHOOK || [ -n "$DISCORD_WEBHOOK" ]; do
						curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Update) New update detected. Installing update.\"}" "$DISCORD_WEBHOOK"
					done < $SCRIPT_DIR/discord_webhooks.txt
				fi
				
				if [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "active" ]]; then
					sleep 1
					WAS_ACTIVE="1"
					script_stop
					sleep 1
				fi
				
				if [[ "$TMPFS_ENABLE" == "1" ]]; then
					rm -rf $TMPFS_DIR/*
				fi
				
				echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Update) Updating..." | tee -a "$LOG_SCRIPT"
				
				rm $SRV_DIR/server.jar
				wget -O $SRV_DIR/server.jar "$JAR_URL"
				
				echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Update) Update completed." | tee -a "$LOG_SCRIPT"
				echo "$LATEST_VERSION" > $UPDATE_DIR/installed.version
				echo "$JAR_SHA1" > $UPDATE_DIR/installed.sha1
				
				if [ "$WAS_ACTIVE" == "1" ]; then
					if [[ "$TMPFS_ENABLE" == "1" ]]; then
						mkdir -p $TMPFS_DIR
						mkdir -p $SRV_DIR
					elif [[ "$TMPFS_ENABLE" == "0" ]]; then
						mkdir -p $SRV_DIR
					fi
					sleep 1
					if [[ "$UPDATE_IGNORE_FAILED_ACTIVATIONS" == "1" ]]; then
						script_start_ignore_errors
					else
						script_start
					fi
				fi
				
				if [[ "$EMAIL_UPDATE" == "1" ]]; then
					mail -r "$EMAIL_SENDER ($NAME-$USER)" -s "Notification: Update" $EMAIL_RECIPIENT <<- EOF
					Server was updated. Please check the update notes if there are any additional steps to take.
					EOF
				fi
				
				if [[ "$DISCORD_UPDATE" == "1" ]]; then
					while IFS="" read -r DISCORD_WEBHOOK || [ -n "$DISCORD_WEBHOOK" ]; do
						curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Update) Server update complete.\"}" "$DISCORD_WEBHOOK"
					done < $SCRIPT_DIR/discord_webhooks.txt
				fi
			elif [[ "$JAR_SHA1" == "$INSTALLED_SHA1" ]]; then
				echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Update) No new updates detected." | tee -a "$LOG_SCRIPT"
				echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Update) Installed: Version: $INSTALLED_VERSION, SHA1: $INSTALLED_SHA1" | tee -a "$LOG_SCRIPT"
			fi
		else
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Update) You have the wrong game type. Aborting." | tee -a  "$LOG_SCRIPT"
		fi
	fi
}

script_spigot_update() {
	if [[ "$GAME_TYPE" == "2" ]]; then
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Spigot update) Update commencing. Waiting on user input..." | tee -a  "$LOG_SCRIPT"
		read -p "Update spigot? (y/n): " UPDATE_SPIGOT
		if [[ "$UPDATE_SPIGOT" =~ ^([yY][eE][sS]|[yY])$ ]]; then
			read -p "Choose spigot revision? (ex. 1.16.1): " REVISION_SPIGOT
			
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Spigot update) Update commencing." | tee -a  "$LOG_SCRIPT"
			
			if [[ "$(systemctl --user show -p ActiveState --value $SERVICE)" == "active" ]]; then
				sleep 1
				WAS_ACTIVE="1"
				script_stop
				sleep 1
			fi
			
			if [[ "$TMPFS_ENABLE" == "1" ]]; then
				rm -rf $TMPFS_DIR/*
			fi
			
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Spigot update) Preparing world for new version." | tee -a  "$LOG_SCRIPT"
			
			( sleep 5 && /usr/bin/tmux -f $SCRIPT_DIR/$SERVICE_NAME-tmux.conf -L $USER-tmux.sock new-session -d -s $NAME 'java -server -XX:+UseG1GC -Xmx6G -Xms1G -Dsun.rmi.dgc.server.gcInterval=2147483646 -XX:+UnlockExperimentalVMOptions -XX:G1NewSizePercent=20 -XX:G1ReservePercent=20 -XX:MaxGCPauseMillis=50 -XX:G1HeapRegionSize=32M -Dfml.ignorePatchDiscrepancies=true -Dfml.ignoreInvalidMinecraftCertificates=true -jar $(ls -v '$SRV_DIR' | grep -i "spigot" | grep -i ".jar" | head -n 1) --forceUpgrade' ) &
			timeout $TIMEOUT /bin/bash -c '
			while read line; do
				if [[ "$line" =~ "[Server thread/INFO]: Done " ]]; then
					echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Spigot update) World preperation complete." | tee -a  "$LOG_SCRIPT"
					/usr/bin/tmux -L $USER-tmux.sock send-keys -t $NAME.0 "stop" ENTER
					sleep 10
					break
				else
					echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Spigot update) Preparing world for the new version. Please wait..."
				fi
			done < <(tail -n1 -f $LOG_TMP)'
			
			SPIGOT_OLD=$(ls -v '$SRV_DIR' | grep -i "spigot" | grep -i ".jar" | head -n 1)
			rm $SRV_DIR/$SPIGOT_OLD
			
			cd /home/$USER/server
			
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Spigot update) Building new version." | tee -a  "$LOG_SCRIPT"
			
			wget -O BuildTools.jar https://hub.spigotmc.org/jenkins/job/BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar
			git config --global --unset core.autocrlf
			java -jar BuildTools.jar --rev $REVISION_SPIGOT
			
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Spigot update) Upgrading world." | tee -a  "$LOG_SCRIPT"
			
			( sleep 5 && /usr/bin/tmux -f $SCRIPT_DIR/$SERVICE_NAME-tmux.conf -L $USER-tmux.sock new-session -d -s $NAME 'java -server -XX:+UseG1GC -Xmx6G -Xms1G -Dsun.rmi.dgc.server.gcInterval=2147483646 -XX:+UnlockExperimentalVMOptions -XX:G1NewSizePercent=20 -XX:G1ReservePercent=20 -XX:MaxGCPauseMillis=50 -XX:G1HeapRegionSize=32M -Dfml.ignorePatchDiscrepancies=true -Dfml.ignoreInvalidMinecraftCertificates=true -jar $(ls -v '$SRV_DIR' | grep -i "spigot" | grep -i ".jar" | head -n 1) --forceUpgrade' ) &
			timeout $TIMEOUT /bin/bash -c '
			while read line; do
				if [[ "$line" =~ "[Server thread/INFO]: Done " ]]; then
					echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Spigot update) World upgrade complete." | tee -a  "$LOG_SCRIPT"
					/usr/bin/tmux -L $USER-tmux.sock send-keys -t $NAME.0 "stop" ENTER
					sleep 10
					break
				else
					echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Spigot update) Upgrading world with the new version. Please wait..."
				fi
			done < <(tail -n1 -f $LOG_TMP)'
			
			if [ "$WAS_ACTIVE" == "1" ]; then
				if [[ "$TMPFS_ENABLE" == "1" ]]; then
					mkdir -p $TMPFS_DIR
					mkdir -p $SRV_DIR
				elif [[ "$TMPFS_ENABLE" == "0" ]]; then
					mkdir -p $SRV_DIR
				fi
				sleep 1
				if [[ "$UPDATE_IGNORE_FAILED_ACTIVATIONS" == "1" ]]; then
					script_start_ignore_errors
				else
					script_start
				fi
			fi
			
			if [[ "$EMAIL_UPDATE" == "1" ]]; then
				mail -r "$EMAIL_SENDER ($NAME-$USER)" -s "Notification: Spigot update" $EMAIL_RECIPIENT <<- EOF
				Spigot was updated. Please check the update notes if there are any additional steps to take.
				EOF
			fi
			
			if [[ "$DISCORD_UPDATE" == "1" ]]; then
				while IFS="" read -r DISCORD_WEBHOOK || [ -n "$DISCORD_WEBHOOK" ]; do
					curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Spigot update) Server update complete.\"}" "$DISCORD_WEBHOOK"
				done < $SCRIPT_DIR/discord_webhooks.txt
			fi
		else
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Spigot update) Update canceled." | tee -a  "$LOG_SCRIPT"
		fi
	else
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Spigot update) You have the wrong game type. Aborting." | tee -a  "$LOG_SCRIPT"
	fi
}

#Install aliases in .bashrc
script_install_alias() {
	if [ "$EUID" -ne "0" ]; then #Check if script executed as root and asign the username for the installation process, otherwise use the executing user
		script_logs
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
			alias $SERVICE_NAME="/home/$USER/scripts/$SERVICE_NAME-script.bash"
		EOF
	fi
	
	if [ "$EUID" -ne "0" ]; then
		if [[ "$INSTALL_BASHRC_ALIAS_STATE" == "1" ]]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Install .bashrc aliases) Installation of aliases in .bashrc complete. Re-log for the changes to take effect." | tee -a "$LOG_SCRIPT"
			echo "Aliases:"
			echo "$SERVICE_NAME -attach = Attaches to the server console."
			echo "$SERVICE_NAME -serversync = Attaches to the ServerSync console."
		fi
	fi
}

#Install tmux configuration for specific server when first ran
script_server_tmux_install() {
	echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Server tmux configuration) Installing tmux configuration for server." | tee -a "$LOG_SCRIPT"
	if [ ! -f /tmp/$USER-$SERVICE_NAME-tmux.conf ]; then
		touch /tmp/$USER-$SERVICE_NAME-tmux.conf
		cat > /tmp/$USER-$SERVICE_NAME-tmux.conf <<- EOF
		#Tmux configuration
		set -g activity-action other
		set -g allow-rename off
		set -g assume-paste-time 1
		set -g base-index 0
		set -g bell-action any
		set -g default-command "${SHELL}"
		#set -g default-terminal "tmux-256color"
		set -g default-terminal "screen-hack_color"
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
		bind-key r source-file /tmp/$USER-$SERVICE_NAME-tmux.conf \; display-message "Config reloaded!"

		set-hook -g session-created 'resize-window -y 24 -x 10000'
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
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$VERSION] [$NAME] [INFO] (Server tmux configuration) Tmux configuration for server installed successfully." | tee -a "$LOG_SCRIPT"
	fi
}

#Install or reinstall systemd services
script_install_services() {
	if [ "$EUID" -ne "0" ]; then #Check if script executed as root and asign the username for the installation process, otherwise use the executing user
		script_logs
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
		if [ ! -d "/home/$USER/.config/systemd/user" ]; then
			mkdir -p /home/$USER/.config/systemd/user
		fi
		
		if [ -f "/home/$USER/.config/systemd/user/$SERVICE_NAME-mkdir-tmpfs.service" ]; then
			rm /home/$USER/.config/systemd/user/$SERVICE_NAME-mkdir-tmpfs.service
		fi
		
		if [ -f "/home/$USER/.config/systemd/user/$SERVICE_NAME-vanilla-tmpfs.service" ]; then
			rm /home/$USER/.config/systemd/user/$SERVICE_NAME-vanilla-tmpfs.service
		fi
		
		if [ -f "/home/$USER/.config/systemd/user/$SERVICE_NAME-vanilla.service" ]; then
			rm /home/$USER/.config/systemd/user/$SERVICE_NAME-vanilla.service
		fi
		
		if [ -f "/home/$USER/.config/systemd/user/$SERVICE_NAME-spigot-tmpfs.service" ]; then
			rm /home/$USER/.config/systemd/user/$SERVICE_NAME-spigot-tmpfs.service
		fi
		
		if [ -f "/home/$USER/.config/systemd/user/$SERVICE_NAME-spigot.service" ]; then
			rm /home/$USER/.config/systemd/user/$SERVICE_NAME-spigot.service
		fi
		
		if [ -f "/home/$USER/.config/systemd/user/$SERVICE_NAME-forge-tmpfs.service" ]; then
			rm /home/$USER/.config/systemd/user/$SERVICE_NAME-forge-tmpfs.service
		fi
		
		if [ -f "/home/$USER/.config/systemd/user/$SERVICE_NAME-forge.service" ]; then
			rm /home/$USER/.config/systemd/user/$SERVICE_NAME-forge.service
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
		
		if [ -f "/home/$USER/.config/systemd/user/$SERVICE_NAME-send-notification@.service" ]; then
			rm /home/$USER/.config/systemd/user/$SERVICE_NAME-send-notification.service
		fi
		
		cat > /home/$USER/.config/systemd/user/$SERVICE_NAME-mkdir-tmpfs.service <<- EOF
		[Unit]
		Description=$NAME TmpFs dir creator
		After=mnt-tmpfs.mount
		
		[Service]
		Type=oneshot
		WorkingDirectory=/home/$USER/
		ExecStart=/bin/mkdir -p $TMPFS_DIR
		
		[Install]
		WantedBy=default.target
		EOF
		
		cat > /home/$USER/.config/systemd/user/$SERVICE_NAME-vanilla-tmpfs.service <<- EOF
		[Unit]
		Description=Minecraft Vanilla TmpFs Server Service
		Requires=$SERVICE_NAME-mkdir-tmpfs.service
		After=network.target mnt-tmpfs.mount $SERVICE_NAME-mkdir-tmpfs.service
		Conflicts=$SERVICE_NAME-vanilla.service
		Conflicts=$SERVICE_NAME-spigot-tmpfs.service
		Conflicts=$SERVICE_NAME-spigot.service
		Conflicts=$SERVICE_NAME-forge-tmpfs.service
		Conflicts=$SERVICE_NAME-forge.service
		StartLimitBurst=3
		StartLimitIntervalSec=300
		StartLimitAction=none
		OnFailure=$SERVICE_NAME-send-notification.service
		
		[Service]
		Type=forking
		WorkingDirectory=$TMPFS_DIR
		ExecStartPre=$SCRIPT_DIR/$SCRIPT_NAME -server_tmux_install
		ExecStartPre=$SCRIPT_DIR/$SCRIPT_NAME -send_notification_start_initialized
		ExecStartPre=/usr/bin/rsync -av --info=progress2 $SRV_DIR/ $TMPFS_DIR
		ExecStart=/usr/bin/tmux -f /tmp/%u-$SERVICE_NAME-tmux.conf -L %u-tmux.sock new-session -d -s $NAME 'java -server -XX:+UseG1GC -Xmx6G -Xms1G -Dsun.rmi.dgc.server.gcInterval=2147483646 -XX:+UnlockExperimentalVMOptions -XX:G1NewSizePercent=20 -XX:G1ReservePercent=20 -XX:MaxGCPauseMillis=50 -XX:G1HeapRegionSize=32M -Dfml.ignorePatchDiscrepancies=true -Dfml.ignoreInvalidMinecraftCertificates=true -jar server.jar nogui'
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
		ExecStopPost=/usr/bin/rm /tmp/%u-$SERVICE_NAME-tmux.log
		ExecStopPost=/usr/bin/rm /tmp/%u-$SERVICE_NAME-tmux.conf
		ExecStopPost=$SCRIPT_DIR/$SCRIPT_NAME -send_notification_stop_complete
		TimeoutStartSec=infinity
		TimeoutStopSec=120
		RestartSec=10
		Restart=on-failure
		
		[Install]
		WantedBy=default.target
		EOF
		
		cat > /home/$USER/.config/systemd/user/$SERVICE_NAME-vanilla.service <<- EOF
		[Unit]
		Description=Minecraft Vanilla Server Service
		After=network.target
		Conflicts=$SERVICE_NAME-vanilla-tmpfs.service
		Conflicts=$SERVICE_NAME-spigot-tmpfs.service
		Conflicts=$SERVICE_NAME-spigot.service
		Conflicts=$SERVICE_NAME-forge-tmpfs.service
		Conflicts=$SERVICE_NAME-forge.service
		StartLimitBurst=3
		StartLimitIntervalSec=300
		StartLimitAction=none
		OnFailure=$SERVICE_NAME-send-notification.service
		
		[Service]
		Type=forking
		WorkingDirectory=$SRV_DIR
		ExecStartPre=$SCRIPT_DIR/$SCRIPT_NAME -server_tmux_install
		ExecStartPre=$SCRIPT_DIR/$SCRIPT_NAME -send_notification_start_initialized
		ExecStart=/usr/bin/tmux -f /tmp/%u-$SERVICE_NAME-tmux.conf -L %u-tmux.sock new-session -d -s $NAME 'java -server -XX:+UseG1GC -Xmx6G -Xms1G -Dsun.rmi.dgc.server.gcInterval=2147483646 -XX:+UnlockExperimentalVMOptions -XX:G1NewSizePercent=20 -XX:G1ReservePercent=20 -XX:MaxGCPauseMillis=50 -XX:G1HeapRegionSize=32M -Dfml.ignorePatchDiscrepancies=true -Dfml.ignoreInvalidMinecraftCertificates=true -jar server.jar nogui'
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
		ExecStopPost=/usr/bin/rm /tmp/%u-$SERVICE_NAME-tmux.log
		ExecStopPost=/usr/bin/rm /tmp/%u-$SERVICE_NAME-tmux.conf
		ExecStopPost=$SCRIPT_DIR/$SCRIPT_NAME -send_notification_stop_complete
		TimeoutStartSec=infinity
		TimeoutStopSec=120
		RestartSec=10
		Restart=on-failure
		
		[Install]
		WantedBy=default.target
		EOF
		
		cat > /home/$USER/.config/systemd/user/$SERVICE_NAME-spigot.service <<- EOF
		[Unit]
		Description=Minecraft Spigot Service
		After=network.target
		Conflicts=$SERVICE_NAME-vanilla-tmpfs.service
		Conflicts=$SERVICE_NAME-vanilla.service
		Conflicts=$SERVICE_NAME-spigot-tmpfs.service
		Conflicts=$SERVICE_NAME-forge-tmpfs.service
		Conflicts=$SERVICE_NAME-forge.service
		StartLimitBurst=3
		StartLimitIntervalSec=300
		StartLimitAction=none
		OnFailure=$SERVICE_NAME-send-notification.service
		
		[Service]
		Type=forking
		WorkingDirectory=$SRV_DIR
		ExecStartPre=$SCRIPT_DIR/$SCRIPT_NAME -server_tmux_install
		ExecStartPre=$SCRIPT_DIR/$SCRIPT_NAME -send_notification_start_initialized
		EOF
		
		echo "ExecStart=/usr/bin/tmux -f /tmp/%u-$SERVICE_NAME-tmux.conf -L %u-tmux.sock new-session -d -s $NAME 'java -server -XX:+UseG1GC -Xmx6G -Xms1G -Dsun.rmi.dgc.server.gcInterval=2147483646 -XX:+UnlockExperimentalVMOptions -XX:G1NewSizePercent=20 -XX:G1ReservePercent=20 -XX:MaxGCPauseMillis=50 -XX:G1HeapRegionSize=32M -Dfml.ignorePatchDiscrepancies=true -Dfml.ignoreInvalidMinecraftCertificates=true -jar "'$(ls -v '$SRV_DIR' | grep -i "spigot" | grep -i ".jar" | head -n 1)'\' >> /home/$USER/.config/systemd/user/$SERVICE_NAME-spigot.service
		
		cat >> /home/$USER/.config/systemd/user/$SERVICE_NAME-spigot.service <<- EOF
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
		ExecStopPost=/usr/bin/rm /tmp/%u-$SERVICE_NAME-tmux.log
		ExecStopPost=/usr/bin/rm /tmp/%u-$SERVICE_NAME-tmux.conf
		ExecStopPost=$SCRIPT_DIR/$SCRIPT_NAME -send_notification_stop_complete
		TimeoutStartSec=infinity
		TimeoutStopSec=120
		RestartSec=10
		Restart=on-failure
		
		[Install]
		WantedBy=default.target
		EOF

		cat > /home/$USER/.config/systemd/user/$SERVICE_NAME-spigot-tmpfs.service <<- EOF
		[Unit]
		Description=Minecraft Spigot TmpFs Server Service
		Requires=$SERVICE_NAME-mkdir-tmpfs.service
		After=network.target mnt-tmpfs.mount $SERVICE_NAME-mkdir-tmpfs.service
		Conflicts=$SERVICE_NAME-vanilla-tmpfs.service
		Conflicts=$SERVICE_NAME-vanilla.service
		Conflicts=$SERVICE_NAME-spigot.service
		Conflicts=$SERVICE_NAME-forge-tmpfs.service
		Conflicts=$SERVICE_NAME-forge.service
		StartLimitBurst=3
		StartLimitIntervalSec=300
		StartLimitAction=none
		OnFailure=$SERVICE_NAME-send-notification.service
		
		[Service]
		Type=forking
		WorkingDirectory=$TMPFS_DIR
		ExecStartPre=$SCRIPT_DIR/$SCRIPT_NAME -server_tmux_install
		ExecStartPre=$SCRIPT_DIR/$SCRIPT_NAME -send_notification_start_initialized
		ExecStartPre=/usr/bin/rsync -av --info=progress2 $SRV_DIR/ $TMPFS_DIR
		EOF
		
		echo "ExecStart=/usr/bin/tmux -f /tmp/%u-$SERVICE_NAME-tmux.conf -L %u-tmux.sock new-session -d -s $NAME 'java -server -XX:+UseG1GC -Xmx6G -Xms1G -Dsun.rmi.dgc.server.gcInterval=2147483646 -XX:+UnlockExperimentalVMOptions -XX:G1NewSizePercent=20 -XX:G1ReservePercent=20 -XX:MaxGCPauseMillis=50 -XX:G1HeapRegionSize=32M -Dfml.ignorePatchDiscrepancies=true -Dfml.ignoreInvalidMinecraftCertificates=true -jar "'$(ls -v '$TMPFS_DIR' | grep -i "spigot" | grep -i ".jar" | head -n 1)'\' >> /home/$USER/.config/systemd/user/$SERVICE_NAME-spigot-tmpfs.service
		
		cat >> /home/$USER/.config/systemd/user/$SERVICE_NAME-spigot-tmpfs.service <<- EOF
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
		ExecStopPost=/usr/bin/rm /tmp/%u-$SERVICE_NAME-tmux.log
		ExecStopPost=/usr/bin/rm /tmp/%u-$SERVICE_NAME-tmux.conf
		ExecStopPost=$SCRIPT_DIR/$SCRIPT_NAME -send_notification_stop_complete
		TimeoutStartSec=infinity
		TimeoutStopSec=120
		RestartSec=10
		Restart=on-failure
		
		[Install]
		WantedBy=default.target
		EOF
		
		cat > /home/$USER/.config/systemd/user/$SERVICE_NAME-forge.service <<- EOF
		[Unit]
		Description=Minecraft Forge Service
		After=network.target
		Conflicts=$SERVICE_NAME-vanilla-tmpfs.service
		Conflicts=$SERVICE_NAME-vanilla.service
		Conflicts=$SERVICE_NAME-spigot-tmpfs.service
		Conflicts=$SERVICE_NAME-spigot.service
		Conflicts=$SERVICE_NAME-forge-tmpfs.service
		StartLimitBurst=3
		StartLimitIntervalSec=300
		StartLimitAction=none
		OnFailure=$SERVICE_NAME-send-notification.service
		
		[Service]
		Type=forking
		WorkingDirectory=$SRV_DIR
		ExecStartPre=$SCRIPT_DIR/$SCRIPT_NAME -server_tmux_install
		ExecStartPre=$SCRIPT_DIR/$SCRIPT_NAME -send_notification_start_initialized
		EOF
		
		echo "ExecStart=/usr/bin/tmux -f /tmp/%u-$SERVICE_NAME-tmux.conf -L %u-tmux.sock new-session -d -s $NAME 'java -server -XX:+UseG1GC -Xmx6G -Xms1G -Dsun.rmi.dgc.server.gcInterval=2147483646 -XX:+UnlockExperimentalVMOptions -XX:G1NewSizePercent=20 -XX:G1ReservePercent=20 -XX:MaxGCPauseMillis=50 -XX:G1HeapRegionSize=32M -Dfml.ignorePatchDiscrepancies=true -Dfml.ignoreInvalidMinecraftCertificates=true -jar "'$(ls -v '$SRV_DIR' | grep -i "forge" | grep -i ".jar" | head -n 1)'\' >> /home/$USER/.config/systemd/user/$SERVICE_NAME-forge.service
		
		cat >> /home/$USER/.config/systemd/user/$SERVICE_NAME-forge.service <<- EOF
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
		ExecStopPost=/usr/bin/rm /tmp/%u-$SERVICE_NAME-tmux.log
		ExecStopPost=/usr/bin/rm /tmp/%u-$SERVICE_NAME-tmux.conf
		ExecStopPost=$SCRIPT_DIR/$SCRIPT_NAME -send_notification_stop_complete
		TimeoutStartSec=infinity
		TimeoutStopSec=120
		RestartSec=10
		Restart=on-failure
		
		[Install]
		WantedBy=default.target
		EOF

		cat > /home/$USER/.config/systemd/user/$SERVICE_NAME-forge-tmpfs.service <<- EOF
		[Unit]
		Description=Minecraft Forge TmpFs Server Service
		Requires=$SERVICE_NAME-mkdir-tmpfs.service
		After=network.target mnt-tmpfs.mount $SERVICE_NAME-mkdir-tmpfs.service
		Conflicts=$SERVICE_NAME-vanilla-tmpfs.service
		Conflicts=$SERVICE_NAME-vanilla.service
		Conflicts=$SERVICE_NAME-spigot-tmpfs.service
		Conflicts=$SERVICE_NAME-spigot.service
		Conflicts=$SERVICE_NAME-forge.service
		StartLimitBurst=3
		StartLimitIntervalSec=300
		StartLimitAction=none
		OnFailure=$SERVICE_NAME-send-notification.service
		
		[Service]
		Type=forking
		WorkingDirectory=$TMPFS_DIR
		ExecStartPre=$SCRIPT_DIR/$SCRIPT_NAME -server_tmux_install
		ExecStartPre=$SCRIPT_DIR/$SCRIPT_NAME -send_notification_start_initialized
		ExecStartPre=/usr/bin/rsync -av --info=progress2 $SRV_DIR/ $TMPFS_DIR
		EOF
		
		echo "ExecStart=/usr/bin/tmux -f /tmp/%u-$SERVICE_NAME-tmux.conf -L %u-tmux.sock new-session -d -s $NAME 'java -server -XX:+UseG1GC -Xmx6G -Xms1G -Dsun.rmi.dgc.server.gcInterval=2147483646 -XX:+UnlockExperimentalVMOptions -XX:G1NewSizePercent=20 -XX:G1ReservePercent=20 -XX:MaxGCPauseMillis=50 -XX:G1HeapRegionSize=32M -Dfml.ignorePatchDiscrepancies=true -Dfml.ignoreInvalidMinecraftCertificates=true -jar "'$(ls -v '$TMPFS_DIR' | grep -i "forge" | grep -i ".jar" | head -n 1)'\' >> /home/$USER/.config/systemd/user/$SERVICE_NAME-forge-tmpfs.service
		
		cat >> /home/$USER/.config/systemd/user/$SERVICE_NAME-forge-tmpfs.service <<- EOF
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
		ExecStopPost=/usr/bin/rm /tmp/%u-$SERVICE_NAME-tmux.log
		ExecStopPost=/usr/bin/rm /tmp/%u-$SERVICE_NAME-tmux.conf
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
		echo "ExecStart=/usr/bin/tmux -f /tmp/%u-$SERVICE_NAME-tmux.conf -L %u-serversync-tmux.sock new-session -d -s ServerSync 'java -jar "'$(ls -v '$SERVER_SYNC_DIR' | grep -i "serversync" | head -n 1) server'\' >> /home/$USER/.config/systemd/user/$SERVICE_NAME-serversync.service
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
	script_logs
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
	script_logs
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
		script_remove_old_files
		script_cleardrops
		script_saveoff
		script_save
		script_sync
		script_autobackup
		script_saveon
		script_update
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
		script_remove_old_files
		script_saveoff
		script_save
		script_sync
		script_saveon
		script_update
		script_update_github
	fi
}

script_diagnostics() {
	echo "Initializing diagnostics. Please wait..."
	sleep 3
	
	#Check package versions
	echo "tmux version: $(tmux -V)"
	echo "rsync version: $(rsync --version | head -n 1)"
	echo "curl version: $(curl --version | head -n 1)"
	echo "wget version: $(wget --version | head -n 1)"
	echo "java version: $(java --showversion)",
	echo "jq version: $(jq --version)"
	echo "postfix version: $(postconf mail_version)"
	
	#Get distro name
	DISTRO=$(cat /etc/os-release | grep "^ID=" | cut -d = -f2)
	
	#Check package versions
	if [[ "$DISTRO" == "arch" ]]; then
		echo "postfix version:$(pacman -Qi postfix | grep "^Version" | cut -d : -f2)"
		echo "zip version:$(pacman -Qi zip | grep "^Version" | cut -d : -f2)"
	elif [[ "$DISTRO" == "ubuntu" ]]; then
		echo "postfix version:$(dpkg -s postfix | grep "^Version" | cut -d : -f2)"
		echo "zip version:$(dpkg -s zip | grep "^Version" | cut -d : -f2)"
	fi
	
	#Check if files/folders present
	if [ -f "$SCRIPT_DIR/$SCRIPT_NAME" ] ; then
		echo "Script installed: Yes"
	else
		echo "Script installed: No"
	fi
	
	if [ -f "$SCRIPT_DIR/$SERVICE_NAME-config.conf" ] ; then
		echo "Configuration file present: Yes"
	else
		echo "Configuration file present: No"
	fi
	
	if [ -d "/home/$USER/backups" ]; then
		echo "Backups folder present: Yes"
	else
		echo "Backups folder present: No"
	fi
	
	if [ -d "/home/$USER/logs" ]; then
		echo "Logs folder present: Yes"
	else
		echo "Logs folder present: No"
	fi
	
	if [ -d "/home/$USER/scripts" ]; then
		echo "Scripts folder present: Yes"
	else
		echo "Scripts folder present: No"
	fi
	
	if [ -d "/home/$USER/server" ]; then
		echo "Server folder present: Yes"
	else
		echo "Server folder present: No"
	fi
	
	if [ -d "/home/$USER/updates" ]; then
		echo "Updates folder present: Yes"
	else
		echo "Updates folder present: No"
	fi
	
	if [ -f "/home/$USER/.config/systemd/user/$SERVICE_NAME-mkdir-tmpfs.service" ]; then
		echo "Tmpfs mkdir service present: Yes"
	else
		echo "Tmpfs mkdir service present: No"
	fi
	
	if [ -f "/home/$USER/.config/systemd/user/$SERVICE_NAME-vanilla-tmpfs.service" ]; then
		echo "Tmpfs service for vanilla present: Yes"
	else
		echo "Tmpfs service for vanilla present: No"
	fi
	
	if [ -f "/home/$USER/.config/systemd/user/$SERVICE_NAME-vanilla.service" ]; then
		echo "Basic service for vanilla present: Yes"
	else
		echo "Basic service for vanilla present: No"
	fi
	
	if [ -f "/home/$USER/.config/systemd/user/$SERVICE_NAME-spigot-tmpfs.service" ]; then
		echo "Tmpfs service for spigot present: Yes"
	else
		echo "Tmpfs service for spigot present: No"
	fi
	
	if [ -f "/home/$USER/.config/systemd/user/$SERVICE_NAME-spigot.service" ]; then
		echo "Basic service for spigot present: Yes"
	else
		echo "Basic service for spigot present: No"
	fi
	
	if [ -f "/home/$USER/.config/systemd/user/$SERVICE_NAME-forge-tmpfs.service" ]; then
		echo "Tmpfs service for forge present: Yes"
	else
		echo "Tmpfs service for forge present: No"
	fi
	
	if [ -f "/home/$USER/.config/systemd/user/$SERVICE_NAME-forge.service" ]; then
		echo "Basic service for forge present: Yes"
	else
		echo "Basic service for forge present: No"
	fi
	
	if [ -f "/home/$USER/.config/systemd/user/$SERVICE_NAME-timer-1.timer" ]; then
		echo "Timer 1 timer present: Yes"
	else
		echo "Timer 1 timer present: No"
	fi
	
	if [ -f "/home/$USER/.config/systemd/user/$SERVICE_NAME-timer-1.service" ]; then
		echo "Timer 1 service present: Yes"
	else
		echo "Timer 1 service present: No"
	fi
	
	if [ -f "/home/$USER/.config/systemd/user/$SERVICE_NAME-timer-2.timer" ]; then
		echo "Timer 2 timer present: Yes"
	else
		echo "Timer 2 timer present: No"
	fi
	
	if [ -f "/home/$USER/.config/systemd/user/$SERVICE_NAME-timer-2.service" ]; then
		echo "Timer 2 service present: Yes"
	else
		echo "Timer 2 service present: No"
	fi
	
	if [ -f "/home/$USER/.config/systemd/user/$SERVICE_NAME-serversync.service" ]; then
		echo "ServerSync service present: Yes"
	else
		echo "ServerSync service present: No"
	fi
	
	if [ -f "/home/$USER/.config/systemd/user/$SERVICE_NAME-send-notification.service" ]; then
		echo "Notification sending service present: Yes"
	else
		echo "Notification sending service present: No"
	fi
	
	echo "Diagnostics complete."
}

script_install_packages() {
	if [ -f "/etc/os-release" ]; then
		#Get distro name
		DISTRO=$(cat /etc/os-release | grep "^ID=" | cut -d = -f2)
		
		#Check for current distro
		if [[ "$DISTRO" == "arch" ]]; then
			#Arch distro
			
			#Add arch linux multilib repository
			echo "[multilib]" >> /etc/pacman.conf
			echo "Include = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf
			
			#Install packages and enable services
			sudo pacman -Syu --noconfirm rsync unzip p7zip wget curl tmux postfix zip jdk8-openjdk jq #jre8-openjdk
		elif [[ "$DISTRO" == "ubuntu" ]]; then
			#Ubuntu distro
			
			#Get codename
			UBUNTU_CODENAME=$(cat /etc/os-release | grep "^UBUNTU_CODENAME=" | cut -d = -f2)
			
			if [[ "$UBUNTU_CODENAME" == "bionic" || "$UBUNTU_CODENAME" == "eoan" || "$UBUNTU_CODENAME" == "focal" || "$UBUNTU_CODENAME" == "groovy" ]]; then
				#Add i386 architecture support
				apt install --yes sudo gnupg
				sudo dpkg --add-architecture i386
				
				#Install software properties common
				sudo apt install --yes software-properties-common
				
				#Check codename and install config for installation
				if [[ "$UBUNTU_CODENAME" == "bionic" ]]; then
					cat >> /etc/apt/sources.list <<- EOF
					#### ubuntu eoan #########
					deb http://archive.ubuntu.com/ubuntu eoan main restricted universe multiverse
					EOF
					
					cat > /etc/apt/preferences.d/eoan.pref <<- EOF
					Package: *
					Pin: release n=$UBUNTU_CODENAME
					Pin-Priority: 10
					
					Package: tmux
					Pin: release n=eoan
					Pin-Priority: 900
					EOF
				fi
				
				#Check for updates and update local repo database
				sudo apt update
				
				#Install packages and enable services
				sudo apt install --yes rsync unzip p7zip wget curl tmux zip postfix jq openjdk-8-jre-headless
			else
				echo "Error: This version of Ubuntu is not supported. Supported versions are: Ubuntu 18.04 LTS (Bionic Beaver), Ubuntu 19.10 (Disco Dingo), Ubuntu 20.04 LTS (Focal Fossa), Ubuntu 20.10 (Groovy Gorilla)"
				echo "Exiting"
				exit 1
			fi
		elif [[ "$DISTRO" == "debian" ]]; then
			#Debian distro
			
			#Get codename
			DEBIAN_CODENAME=$(cat /etc/os-release | grep "^VERSION_CODENAME=" | cut -d = -f2)
			
			if [[ "$DEBIAN_CODENAME" == "buster" ]]; then
				#Add i386 architecture support
				apt install --yes sudo gnupg
				sudo dpkg --add-architecture i386
				
				#Install software properties common
				sudo apt install --yes software-properties-common
				
				#Add non-free repo for steamcmd
				sudo apt-add-repository non-free
				
				#Check codename and install backport repo if needed
				if [[ "$DEBIAN_CODENAME" == "buster" ]]; then
					sudo apt-add-repository "deb http://deb.debian.org/debian $DEBIAN_CODENAME-backports main"
					sudo apt update
					sudo apt -t buster-backports install --yes "tmux"
				fi
				
				#Check for updates and update local repo database
				sudo apt update
				
				#Install packages and enable services
				sudo apt install --yes rsync unzip p7zip wget curl tmux zip postfix jq openjdk-8-jre-headless
			else
				echo "Error: This version of Debian is not supported. Supported versions are: Debian 10 (Buster)"
				echo "Exiting"
				exit 1
			fi
		else
			echo "Error: This distro is not supported. This script currently supports Arch Linux, Ubuntu 18.04 LTS (Bionic Beaver), Ubuntu 19.10 (Disco Dingo), Ubuntu 20.04 LTS (Focal Fossa), Ubuntu 20.10 (Groovy Gorilla), Debian 10 (Buster). If you want to try the script on your distro, install the packages manually. Check the readme for required package versions."
			echo "Exiting"
			exit 1
		fi
		
		echo "Package installation complete."
	else
		echo "os-release file not found. Is this distro supported?"
		echo "This script currently supports Arch Linux, Ubuntu 18.04 LTS (Bionic Beaver), Ubuntu 19.10 (Disco Dingo), Ubuntu 20.04 LTS (Focal Fossa), Ubuntu 20.10 (Groovy Gorilla), Debian 10 (Buster)"
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
	echo "tmux (minimum version: 2.9a)"
	echo "curl"
	echo "jq"
	echo "wget"
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
	echo "/home/$USER/.config/systemd/user/$SERVICE_NAME-vanilla-tmpfs.service - Server service file for use with a RamDisk (only executes if RamDisk enabled)."
	echo "/home/$USER/.config/systemd/user/$SERVICE_NAME-vanilla.service - Server service file for normal hdd/ssd use."
	echo "/home/$USER/.config/systemd/user/$SERVICE_NAME-spigot-tmpfs.service - Server service file for use with a RamDisk (only executes if RamDisk enabled)."
	echo "/home/$USER/.config/systemd/user/$SERVICE_NAME-spigot.service - Server service file for normal hdd/ssd use."
	echo "/home/$USER/.config/systemd/user/$SERVICE_NAME-forge-tmpfs.service - Server service file for use with a RamDisk (only executes if RamDisk enabled)."
	echo "/home/$USER/.config/systemd/user/$SERVICE_NAME-forge.service - Server service file for normal hdd/ssd use."
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
	
	sudo chown -R "$USER":users "/home/$USER"
	
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
	else
		TMPFS_ENABLE="0"
	fi
	
	echo ""
	echo "Select your Minecraft server type:"
	echo "1 - Vanilla"
	echo "2 - Spigot"
	echo "3 - Forge"
	read -p "Enter type (ex. 1): " GAME_TYPE
	
	if [[ "$GAME_TYPE" == "1" ]]; then
		echo ""
		read -p "Enable automatic updates for the vanilla minecraft server (y/n): " UPDATE_CONFIG
		SCRIPT_UPDATE_CONFIG=${UPDATE_CONFIG:=n}
		if [[ "$UPDATE_CONFIG" =~ ^([yY][eE][sS]|[yY])$ ]]; then
			UPDATE_ENABLED="1"
		else
			UPDATE_ENABLED="0"
		fi
	elif [[ "$GAME_TYPE" == "2" ]]; then
		read -p "Choose spigot revision: (ex. 1.16.1): " REVISION_SPIGOT
		UPDATE_ENABLED="0"
	else
		UPDATE_ENABLED="0"
	fi
	
	echo ""
	read -p "Enable automatic updates for the script from github? Read warning in readme! (y/n): " SCRIPT_UPDATE_CONFIG
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
		read -p "Email notifications for game updates? (y/n): " POSTFIX_UPDATE_ENABLE
			if [[ "$POSTFIX_UPDATE_ENABLE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
				POSTFIX_UPDATE="1"
			else
				POSTFIX_UPDATE="0"
			fi
		echo ""
		read -p "Email notifications for script updates from github? (y/n): " POSTFIX_UPDATE_SCRIPT_ENABLE
			if [[ "$POSTFIX_UPDATE_SCRIPT_ENABLE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
				POSTFIX_UPDATE_SCRIPT="1"
			else
				POSTFIX_UPDATE_SCRIPT="0"
			fi
		echo ""
		read -p "Email notifications for server startup? (WARNING: this can be anoying) (y/n): " POSTFIX_CRASH_ENABLE
			if [[ "$POSTFIX_CRASH_ENABLE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
				POSTFIX_START="1"
			else
				POSTFIX_START="0"
			fi
		echo ""
		read -p "Email notifications for server shutdown? (WARNING: this can be anoying) (y/n): " POSTFIX_CRASH_ENABLE
			if [[ "$POSTFIX_CRASH_ENABLE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
				POSTFIX_STOP="1"
			else
				POSTFIX_STOP="0"
			fi
		echo ""
		read -p "Email notifications for crashes? (y/n): " POSTFIX_CRASH_ENABLE
			if [[ "$POSTFIX_CRASH_ENABLE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
				POSTFIX_CRASH="1"
			else
				POSTFIX_CRASH="0"
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
		POSTFIX_UPDATE="0"
		POSTFIX_UPDATE_SCRIPT="0"
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
		if [[ "$DISCORD_WEBHOOK" == "" ]]; then
			DISCORD_WEBHOOK="none"
		fi
		echo ""
		read -p "Discord notifications for game updates? (y/n): " DISCORD_UPDATE_ENABLE
			if [[ "$DISCORD_UPDATE_ENABLE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
				DISCORD_UPDATE="1"
			else
				DISCORD_UPDATE="0"
			fi
		echo ""
		read -p "Discord notifications for script updates from github? (y/n): " DISCORD_UPDATE_SCRIPT_ENABLE
			if [[ "$DISCORD_UPDATE_SCRIPT_ENABLE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
				DISCORD_UPDATE_SCRIPT="1"
			else
				DISCORD_UPDATE_SCRIPT="0"
			fi
		echo ""
		read -p "Discord notifications for server startup? (y/n): " DISCORD_START_ENABLE
			if [[ "$DISCORD_START_ENABLE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
				DISCORD_START="1"
			else
				DISCORD_START="0"
			fi
		echo ""
		read -p "Discord notifications for server shutdown? (y/n): " DISCORD_STOP_ENABLE
			if [[ "$DISCORD_STOP_ENABLE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
				DISCORD_STOP="1"
			else
				DISCORD_STOP="0"
			fi
		echo ""
		read -p "Discord notifications for crashes? (y/n): " DISCORD_CRASH_ENABLE
			if [[ "$DISCORD_CRASH_ENABLE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
				DISCORD_CRASH="1"
			else
				DISCORD_CRASH="0"
			fi
	elif [[ "$DISCORD_ENABLE" =~ ^([nN][oO]|[nN])$ ]]; then
		DISCORD_UPDATE="0"
		DISCORD_UPDATE_SCRIPT="0"
		DISCORD_START="0"
		DISCORD_STOP="0"
		DISCORD_CRASH="0"
	fi
	
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
	
	echo "Enabling linger"
	
	sudo loginctl enable-linger $USER
	
	if [ ! -f /var/lib/systemd/linger/$USER ]; then
		sudo mkdir -p /var/lib/systemd/linger/
		sudo touch /var/lib/systemd/linger/$USER
	fi
	
	echo "Enabling services"
	
	sudo systemctl start user@$(id -u $USER).service
	
	su - $USER -c "systemctl --user enable $SERVICE_NAME-timer-1.timer"
	su - $USER -c "systemctl --user enable $SERVICE_NAME-timer-2.timer"
	
	if [[ "$TMPFS" =~ ^([yY][eE][sS]|[yY])$ ]]; then
		su - $USER -c "systemctl --user enable $SERVICE_NAME-mkdir-tmpfs.service"
		if [[ "$GAME_TYPE" == "1" ]]; then
			su - $USER -c "systemctl --user enable $SERVICE_NAME-vanilla-tmpfs.service"
		elif [[ "$GAME_TYPE" == "2" ]]; then
			su - $USER -c "systemctl --user enable $SERVICE_NAME-spigot-tmpfs.service"
		elif [[ "$GAME_TYPE" == "3" ]]; then
			su - $USER -c "systemctl --user enable $SERVICE_NAME-forge-tmpfs.service"
		fi
	elif [[ "$TMPFS" =~ ^([nN][oO]|[nN])$ ]]; then
		if [[ "$GAME_TYPE" == "1" ]]; then
			su - $USER -c "systemctl --user enable $SERVICE_NAME-vanilla.service"
		elif [[ "$GAME_TYPE" == "2" ]]; then
			su - $USER -c "systemctl --user enable $SERVICE_NAME-spigot.service"
		elif [[ "$GAME_TYPE" == "3" ]]; then
			su - $USER -c "systemctl --user enable $SERVICE_NAME-forge.service"
		fi
	fi
	
	echo "Creating folder structure for server..."
	mkdir -p /home/$USER/{backups,logs,scripts,server,updates}
	cp "$(readlink -f $0)" $SCRIPT_DIR
	chmod +x $SCRIPT_DIR/$SCRIPT_NAME
	
	if [[ "$SERVERSYNC_INSTALL" == "1" ]]; then
		echo "Downloading and installing ServerSync from github."
		mkdir -p /home/$USER/serversync
		curl -s https://api.github.com/repos/superzanti/ServerSync/releases/latest | jq -r ".assets[] | select(.name | contains(\"jar\")) | .browser_download_url" | wget -i -
		mv *serversync* /home/$USER/serversync
		sudo chown -R $USER:users /home/$USER/serversync
		su - $USER -c "systemctl --user enable $SERVICE_NAME-serversync.service"
	fi
	
	touch $SCRIPT_DIR/$SERVICE_NAME-config.conf
	echo 'tmpfs_enable='"$TMPFS_ENABLE" >> $SCRIPT_DIR/$SERVICE_NAME-config.conf
	echo 'type='"$GAME_TYPE" >> $SCRIPT_DIR/$SERVICE_NAME-config.conf
	echo 'email_sender='"$POSTFIX_SENDER" >> $SCRIPT_DIR/$SERVICE_NAME-config.conf
	echo 'email_recipient='"$POSTFIX_RECIPIENT" >> $SCRIPT_DIR/$SERVICE_NAME-config.conf
	echo 'email_update='"$POSTFIX_UPDATE" >> $SCRIPT_DIR/$SERVICE_NAME-config.conf
	echo 'email_update_script='"$POSTFIX_UPDATE_SCRIPT" >> $SCRIPT_DIR/$SERVICE_NAME-config.conf
	echo 'email_start='"$POSTFIX_START" >> $SCRIPT_DIR/$SERVICE_NAME-config.conf
	echo 'email_stop='"$POSTFIX_STOP" >> $SCRIPT_DIR/$SERVICE_NAME-config.conf
	echo 'email_crash='"$POSTFIX_CRASH" >> $SCRIPT_DIR/$SERVICE_NAME-config.conf
	echo 'discord_update='"$DISCORD_UPDATE" >> $SCRIPT_DIR/$SERVICE_NAME-config.conf
	echo 'discord_update_script='"$DISCORD_UPDATE_SCRIPT" >> $SCRIPT_DIR/$SERVICE_NAME-config.conf
	echo 'discord_start='"$DISCORD_START" >> $SCRIPT_DIR/$SERVICE_NAME-config.conf
	echo 'discord_stop='"$DISCORD_STOP" >> $SCRIPT_DIR/$SERVICE_NAME-config.conf
	echo 'discord_crash='"$DISCORD_CRASH" >> $SCRIPT_DIR/$SERVICE_NAME-config.conf
	echo 'updates='"$UPDATE_ENABLED" >> $SCRIPT_DIR/$SERVICE_NAME-config.conf
	echo 'script_updates='"$SCRIPT_UPDATE_ENABLED" >> $SCRIPT_DIR/$SERVICE_NAME-config.conf
	echo 'bckp_delold=14' >> $SCRIPT_DIR/$SERVICE_NAME-config.conf
	echo 'log_delold=7' >> $SCRIPT_DIR/$SERVICE_NAME-config.conf
	echo 'serversync='"$SERVERSYNC_INSTALL" >> $SCRIPT_DIR/$SERVICE_NAME-config.conf
	
	echo "$DISCORD_WEBHOOK" > $SCRIPT_DIR/discord_webhooks.txt
	
	sudo chown -R "$USER":users "/home/$USER"
	
	echo "Installing game..."
	
	if [[ "$GAME_TYPE" == "1" ]]; then
		LATEST_VERSION=$(curl -s "https://launchermeta.mojang.com/mc/game/version_manifest.json" | jq -r '.latest.release')
		JSON_URL=$(curl -s "https://launchermeta.mojang.com/mc/game/version_manifest.json" | jq ".versions[] | select(.id==\"$LATEST_VERSION\") .url" | sed 's/"//g')
		JAR_SHA1=$(curl -s "$JSON_URL" | jq '.downloads.server .sha1' | sed 's/"//g')
		JAR_URL=$(curl -s "$JSON_URL" | jq '.downloads.server .url' | sed 's/"//g')
		wget -O /home/$USER/server.jar "$JAR_URL"
	elif [[ "$GAME_TYPE" == "2" ]]; then
		su - $USER -c "cd /home/$USER/server && wget -O BuildTools.jar https://hub.spigotmc.org/jenkins/job/BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar"
		su - $USER -c "git config --global --unset core.autocrlf"
		su - $USER -c "cd /home/$USER/server && java -jar BuildTools.jar --rev $REVISION_SPIGOT"
	fi
	
	touch $SRV_DIR/eula.txt
	echo "eula=true" > $SRV_DIR/eula.txt
	
	sudo chown -R "$USER":users "/home/$USER"
	
	echo "Installation complete"
	echo ""
	echo "You can login to your the $USER account with <sudo -i -u $USER> from your primary account or root account."
	echo "The script was automaticly copied to the scripts folder located at $SCRIPT_DIR"
	echo "For any settings you'll want to change, edit the $SCRIPT_DIR/$SERVICE_NAME-config.conf file."
	echo ""
}

#Do not allow for another instance of this script to run to prevent data loss
if [[ "-send_notification_start_initialized" != "$1" ]] && [[ "-send_notification_start_complete" != "$1" ]] && [[ "-send_notification_stop_initialized" != "$1" ]] && [[ "-send_notification_stop_complete" != "$1" ]] && [[ "-send_notification_crash" != "$1" ]] && [[ "-server_tmux_install" != "$1" ]] && [[ "-attach" != "$1" ]] && [[ "-status" != "$1" ]]; then
	SCRIPT_PID_CHECK=$(basename -- "$0")
	if pidof -x "$SCRIPT_PID_CHECK" -o $$ > /dev/null; then
		echo "An another instance of this script is already running, please clear all the sessions of this script before starting a new session"
		exit 1
	fi
fi

if [ "$EUID" -ne "0" ] && [ -f "$SCRIPT_DIR/$SERVICE_NAME-config.conf" ]; then #Check if script executed as root, if not generate missing config fields
	touch $SCRIPT_DIR/$SERVICE_NAME-config.conf
	CONFIG_FIELDS="tmpfs_enable,type,email_sender,email_recipient,email_update_script,email_start,email_stop,email_crash,discord_update_script,discord_start,discord_stop,discord_crash,update,script_updates,bckp_delold,log_delold,serversync,update_ignore_failed_startups"
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
		echo -e "${GREEN}-diag ${RED}- ${GREEN}Prints out package versions and if script files are installed${NC}"
		echo -e "${GREEN}-start ${RED}- ${GREEN}Start the server${NC}"
		echo -e "${GREEN}-start_no_err ${RED}- ${GREEN}Start the server but don't require confimation if in failed state${NC}"
		echo -e "${GREEN}-stop ${RED}- ${GREEN}Stop the server${NC}"
		echo -e "${GREEN}-restart ${RED}- ${GREEN}Restart the server${NC}"
		echo -e "${GREEN}-autorestart ${RED}- ${GREEN}Automaticly restart the server if it's not running${NC}"
		echo -e "${GREEN}-save ${RED}- ${GREEN}Issue the save command to the server${NC}"
		echo -e "${GREEN}-sync ${RED}- ${GREEN}Sync from tmpfs to hdd/ssd${NC}"
		echo -e "${GREEN}-backup ${RED}- ${GREEN}Backup files, if server running or not${NC}"
		echo -e "${GREEN}-autobackup ${RED}- ${GREEN}Automaticly backup files when server running${NC}"
		echo -e "${GREEN}-deloldbackup ${RED}- ${GREEN}Delete old backups${NC}"
		echo -e "${GREEN}-install_aliases ${RED}- ${GREEN}Installs .bashrc aliases for easy access to the server tmux session${NC}"
		echo -e "${GREEN}-rebuild_services ${RED}- ${GREEN}Reinstalls the systemd services from the script. Usefull if any service updates occoured${NC}"
		echo -e "${GREEN}-disable_services ${RED}- ${GREEN}Disables all services. The server and the script will not start up on boot anymore${NC}"
		echo -e "${GREEN}-enable_services ${RED}- ${GREEN}Enables all services dependant on the configuration file of the script${NC}"
		echo -e "${GREEN}-reload_services ${RED}- ${GREEN}Reloads all services, dependant on the configuration file${NC}"
		echo -e "${GREEN}-update ${RED}- ${GREEN}Update the spigot server, if the server is running it wil save it, shut it down, update it and restart it.${NC}"
		echo -e "${GREEN}-update_spigot ${RED}- ${GREEN}Update the server, if the server is running it wil save it, shut it down, update it and restart it.${NC}"
		echo -e "${GREEN}-update_script ${RED}- ${GREEN}Check github for script updates and update if newer version available${NC}"
		echo -e "${GREEN}-update_script_force ${RED}- ${GREEN}Get latest script from github and install it no matter what the version${NC}"
		echo -e "${GREEN}-status ${RED}- ${GREEN}Display status of server${NC}"
		echo -e "${GREEN}-install ${RED}- ${GREEN}Installs all the needed files for the script to run, the wine prefix and the game${NC}"
		echo -e "${GREEN}-install_packages ${RED}- ${GREEN}Installs all the needed packages (check supported distros)${NC}"
		echo ""
		echo -e "${LIGHTRED}If this is your first time running the script:${NC}"
		echo -e "${LIGHTRED}Use the -install argument (run only this command as root) and follow the instructions${NC}"
		echo ""
		echo -e "${LIGHTRED}After that reboot the server and the game should start on it's own on boot."
		echo ""
		echo -e "${LIGHTRED}Example usage: ./$SCRIPT_NAME -start${NC}"
		echo ""
		echo -e "${CYAN}Have a nice day!${NC}"
		echo ""
		;;
	-diag)
		script_diagnostics
		;;
	-start)
		script_start
		;;
	-start_no_err)
		script_start_ignore_errors $2
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
	-update)
		script_update
		;;
	-update_spigot)
		script_spigot_update
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
	-attach)
		script_attach
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
	-server_tmux_install)
		script_server_tmux_install
		;;
	-install_packages)
		script_install_packages
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
	echo "Usage: $0 {diag|start|start_no_err|stop|restart|saveon|saveoff|save|cleardrops|sync|backup|autobackup|deloldbackup|install_aliases|rebuild_services|disable_services|enable_services|reload_services|update|update_spigot|update_script|update_script_force|attach|status|install}"
	exit 1
	;;
esac

exit 0


#if [[ "$(systemctl --user is-active $SERVICE)" != "active" ]]; then

