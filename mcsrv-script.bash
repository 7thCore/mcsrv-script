#!/bin/bash

#    Copyright (C) 2022 7thCore
#    This file is part of McSrv-Script.
#
#    McSrv-Script is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    McSrv-Script is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

#Minecraft server script by 7thCore
#If you do not know what any of these settings are you are better off leaving them alone. One thing might brake the other if you fiddle around with it.

#Static script variables
export NAME="McSrv" #Name of the tmux session.
export VERSION="1.5-4" #Package and script version.
export SERVICE_NAME="mcsrv" #Name of the service files, user, script and script log.
export LOG_DIR="/srv/$SERVICE_NAME/logs" #Location of the script's log files.
export LOG_STRUCTURE="$LOG_DIR/$(date +"%Y")/$(date +"%m")/$(date +"%d")" #Folder structure of the script's log files.
SRV_DIR="/srv/$SERVICE_NAME/server" #Location of the server located on your hdd/ssd.
TMPFS_DIR="/srv/$SERVICE_NAME/tmpfs" #Locaton of your tmpfs partition.
CONFIG_DIR="/srv/$SERVICE_NAME/config" #Location of script configuration.
ENV_DIR="/srv/$SERVICE_NAME/environments" #Location of server environment configurations.
UPDATE_DIR="/srv/$SERVICE_NAME/updates" #Location of update information for the script's automatic update feature.
BCKP_DIR="/srv/$SERVICE_NAME/backups" #Location of stored backups.
BCKP_STRUCTURE="$(date +"%Y")/$(date +"%m")/$(date +"%d")" #How backups are sorted, by default it's sorted in folders by month and day.

#Script config file variables
BCKP_DELOLD=$(cat $CONFIG_DIR/$SERVICE_NAME-script.conf 2> /dev/null | grep script_bckp_delold= | cut -d = -f2) #Defines how many days old backups are deleted.
LOG_DELOLD=$(cat $CONFIG_DIR/$SERVICE_NAME-script.conf 2> /dev/null | grep script_log_delold= | cut -d = -f2) #Defines how many days old logs are deleted.
LOG_GAME_DELOLD=$(cat $CONFIG_DIR/$SERVICE_NAME-script.conf 2> /dev/null | grep script_log_game_delold= | cut -d = -f2) #Defines how many days old games logs are deleted.
GAME_SERVER_UPDATES=$(cat $CONFIG_DIR/$SERVICE_NAME-script.conf 2> /dev/null | grep script_update_game= | cut -d = -f2) #Defines if automatic game updates are active.
UPDATE_IGNORE_FAILED_ACTIVATIONS=$(cat $CONFIG_DIR/$SERVICE_NAME-script.conf 2> /dev/null | grep script_update_ignore_failed_startups= | cut -d = -f2) #Defines if errors during startup after updates should be ignored.
TIMEOUT_SAVE=$(cat $CONFIG_DIR/$SERVICE_NAME-script.conf 2> /dev/null | grep script_timeout_save= | cut -d = -f2) #Defines how much time in seconds the script waits for the certain functions to complete.
TMPFS_SPACE=$(cat $CONFIG_DIR/$SERVICE_NAME-script.conf 2> /dev/null | grep script_tmpfs_space= | cut -d = -f2) #Defines how much can the tmpfs parition be filled until an automatic server shutdown is issued.

#Script config variables if config doesn't exist
BCKP_DELOLD=${BCKP_DELOLD:="7"} #If the variable for old backup deletion is not defined, assign a default value.
LOG_DELOLD=${LOG_DELOLD:="7"} #If the variable for old log deletion is not defined, assign a default value.
LOG_GAME_DELOLD=${LOG_GAME_DELOLD:="7"} #If the variable for old game log deletion is not defined, assign a default value.
GAME_SERVER_UPDATES=${GAME_SERVER_UPDATES:="0"} #If the variable for game server updates is not defined, assign a default value.
UPDATE_IGNORE_FAILED_ACTIVATIONS=${UPDATE_IGNORE_FAILED_ACTIVATIONS:="0"} #If the variable for ignoring errors after updates is not defined, assign a default value.
TIMEOUT_SAVE=${TIMEOUT_SAVE:="120"} #If the variable for save timeout is not defined, assign a default value.
TMPFS_SPACE=${TMPFS_SPACE:="90"} #If the variable for tmpfs space is not defined, assign a default value.

#Discord config file variables
DISCORD_UPDATE=$(cat $CONFIG_DIR/$SERVICE_NAME-discord.conf 2> /dev/null | grep discord_update= | cut -d = -f2) #Send notification when the server updates.
DISCORD_START=$(cat $CONFIG_DIR/$SERVICE_NAME-discord.conf 2> /dev/null | grep discord_start= | cut -d = -f2) #Send notifications when the server starts.
DISCORD_STOP=$(cat $CONFIG_DIR/$SERVICE_NAME-discord.conf 2> /dev/null | grep discord_stop= | cut -d = -f2) #Send notifications when the server stops.
DISCORD_CRASH=$(cat $CONFIG_DIR/$SERVICE_NAME-discord.conf 2> /dev/null | grep discord_crash= | cut -d = -f2) #Send notifications when the server crashes.
DISCORD_TMPFS_SPACE=$(cat $CONFIG_DIR/$SERVICE_NAME-discord.conf 2> /dev/null | grep discord_tmpfs_space= | cut -d = -f2) #Send notifications if tmpfs space is over the designated percentage.
DISCORD_COLOR_PRESTART=$(cat $CONFIG_DIR/$SERVICE_NAME-discord.conf 2> /dev/null | grep discord_color_prestart= | cut -d = -f2) #Discord embed color for prestart.
DISCORD_COLOR_POSTSTART=$(cat $CONFIG_DIR/$SERVICE_NAME-discord.conf 2> /dev/null | grep discord_color_poststart= | cut -d = -f2) #Discord embed color for poststart.
DISCORD_COLOR_PRESTOP=$(cat $CONFIG_DIR/$SERVICE_NAME-discord.conf 2> /dev/null | grep discord_color_prestop= | cut -d = -f2) #Discord embed color for prestop.
DISCORD_COLOR_POSTSTOP=$(cat $CONFIG_DIR/$SERVICE_NAME-discord.conf 2> /dev/null | grep discord_color_poststop= | cut -d = -f2) #Discord embed color for poststop.
DISCORD_COLOR_UPDATE=$(cat $CONFIG_DIR/$SERVICE_NAME-discord.conf 2> /dev/null | grep discord_color_update= | cut -d = -f2) #Discord embed color for update.
DISCORD_COLOR_CRASH=$(cat $CONFIG_DIR/$SERVICE_NAME-discord.conf 2> /dev/null | grep discord_color_crash= | cut -d = -f2) #Discord embed color for crash.
DISCORD_COLOR_TMPFS_SPACE=$(cat $CONFIG_DIR/$SERVICE_NAME-discord.conf 2> /dev/null | grep discord_color_tmpfs_space= | cut -d = -f2) #Discord embed color for tmpfs space.

#Discord config variables if config doesn't exist
DISCORD_UPDATE=${DISCORD_UPDATE:="0"} #If the variable for discord update is not defined, assign a default value.
DISCORD_START=${DISCORD_START:="0"} #If the variable for discord start is not defined, assign a default value.
DISCORD_STOP=${DISCORD_STOP:="0"} #If the variable for discord stop is not defined, assign a default value.
DISCORD_CRASH=${DISCORD_CRASH:="0"} #If the variable for discord crash is not defined, assign a default value.
DISCORD_TMPFS_SPACE=${DISCORD_TMPFS_SPACE:="0"} #If the variable for discord tmpfs space is not defined, assign a default value.
DISCORD_COLOR_PRESTART=${DISCORD_COLOR_PRESTART:="16776960"} #If the variable discord pre-start color is not defined, assign a default value.
DISCORD_COLOR_POSTSTART=${DISCORD_COLOR_POSTSTART:="65280"} #If the variable discord post-start color is not defined, assign a default value.
DISCORD_COLOR_PRESTOP=${DISCORD_COLOR_PRESTOP:="16776960"} #If the variable discord pre-stop color is not defined, assign a default value.
DISCORD_COLOR_POSTSTOP=${DISCORD_COLOR_POSTSTOP:="65280"} #If the variable discord post-stop color is not defined, assign a default value.
DISCORD_COLOR_UPDATE=${DISCORD_COLOR_UPDATE:="47083"} #If the variable discord update color is not defined, assign a default value.
DISCORD_COLOR_CRASH=${DISCORD_COLOR_CRASH:="16711680"} #If the variable for discord crash color is not defined, assign a default value.
DISCORD_COLOR_TMPFS_SPACE=${DISCORD_COLOR_TMPFS_SPACE:="16711680"} #If the variable for discord tmpfs space color is not defined, assign a default value.

#Email config file variables
EMAIL_SENDER=$(cat $CONFIG_DIR/$SERVICE_NAME-email.conf 2> /dev/null | grep email_sender= | cut -d = -f2) #Send emails from this address.
EMAIL_RECIPIENT=$(cat $CONFIG_DIR/$SERVICE_NAME-email.conf 2> /dev/null | grep email_recipient= | cut -d = -f2) #Send emails to this address.
EMAIL_UPDATE=$(cat $CONFIG_DIR/$SERVICE_NAME-email.conf 2> /dev/null | grep email_update= | cut -d = -f2) #Send emails when server updates.
EMAIL_START=$(cat $CONFIG_DIR/$SERVICE_NAME-email.conf 2> /dev/null | grep email_start= | cut -d = -f2) #Send emails when the server starts up.
EMAIL_STOP=$(cat $CONFIG_DIR/$SERVICE_NAME-email.conf 2> /dev/null | grep email_stop= | cut -d = -f2) #Send emails when the server shuts down.
EMAIL_CRASH=$(cat $CONFIG_DIR/$SERVICE_NAME-email.conf 2> /dev/null | grep email_crash= | cut -d = -f2) #Send emails when the server crashes.
EMAIL_TMPFS_SPACE=$(cat $CONFIG_DIR/$SERVICE_NAME-email.conf 2> /dev/null | grep email_tmpfs_space= | cut -d = -f2) #Send emails if tmpfs space is over the designated percentage.

#Email config variables if config doesn't exist
EMAIL_SENDER=${EMAIL_SENDER:="none"} #If the variable for email sender is not defined, assign a default value.
EMAIL_RECIPIENT=${EMAIL_RECIPIENT:="none"} #If the variable for email recipient is not defined, assign a default value.
EMAIL_UPDATE=${EMAIL_UPDATE:="0"} #If the variable for email update is not defined, assign a default value.
EMAIL_START=${EMAIL_START:="0"} #If the variable for email start is not defined, assign a default value.
EMAIL_STOP=${EMAIL_STOP:="0"} #If the variable for email stop is not defined, assign a default value.
EMAIL_CRASH=${EMAIL_CRASH:="0"} #If the variable for email crash is not defined, assign a default value.
EMAIL_TMPFS_SPACE=${EMAIL_TMPFS_SPACE:="0"} #If the variable for email tmpfs space is not defined, assign a default value.

#Console collors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
LIGHTRED='\033[1;31m'
NC='\033[0m'

#--------------------------
#-- End of configuration --
#--------------------------

#Generate log folder structure
script_logs() {
	#If there is not a folder for today, create one
	if [ ! -d "$LOG_STRUCTURE" ]; then
		mkdir -p "$LOG_STRUCTURE"
	fi
}

#--------------------------

#Discord webhook message send
script_discord_message() {
	while IFS="" read -r DISCORD_WEBHOOK || [ -n "$DISCORD_WEBHOOK" ]; do
		curl -H "Content-Type: application/json" -X POST -d "{\"embeds\": [{ \"author\": { \"name\": \"$NAME Script\", \"url\": \"https://github.com/7thCore/$SERVICE_NAME-script\" }, \"color\": \"$1\", \"description\": \"$2\", \"footer\": {\"text\": \"Version $VERSION\"}, \"timestamp\": \"$(date -u --iso-8601=seconds)\"}] }" "$DISCORD_WEBHOOK"
	done < $CONFIG_DIR/discord_webhooks.txt
}

#--------------------------

#Send email message
script_email_message() {
	mail -r "$EMAIL_SENDER ($1)" -s "$2" $EMAIL_RECIPIENT <<- EOF
	$3
	EOF
}

#--------------------------

#Attaches to the server tmux session
script_attach() {
	if [ -z "$1" ]; then
		echo "[$NAME $VERSION] (Attach) Failed to attach. Specify server ID: $SCRIPT_NAME -attach ID"
	else
		tmux -L $SERVICE_NAME-$1-tmux.sock has-session -t $NAME 2>/dev/null
		if [ $? == 0 ]; then
			echo "[$NAME $VERSION] (Attach) User attached to server session with ID: $1"
			tmux -L $SERVICE_NAME-$1-tmux.sock attach -t $NAME
			echo "[$NAME $VERSION] (Attach) User deattached from server session with ID: $1"
		else
			echo "[$NAME $VERSION] (Attach) Failed to attach to server session with ID: $1"
		fi
	fi
}

#--------------------------

#Deletes old files
script_remove_old_files() {
	script_logs
	echo "[$NAME $VERSION] (Remove old files) Beginning removal of old files."
	for SERVER_SERVICE in $(systemctl --user list-units -all --no-legend --no-pager --plain $SERVICE_NAME@*.service $SERVICE_NAME-tmpfs@*.service | awk '{print $1}'); do
		SERVER_INSTANCE=$(echo $SERVER_SERVICE | awk -F '@' '{print $2}' | awk -F '.service' '{print $1}')
		if [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "active" ]] && [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "enabled" ]]; then
			echo "[$NAME $VERSION] (Remove old files) Deleting old backups for $SERVER_INSTANCE: $BCKP_DELOLD days old."
			# Delete old backups
			find $BCKP_DIR/$SERVER_INSTANCE/* -type f -mtime +$BCKP_DELOLD -delete
			# Delete empty folders
			echo "[$NAME $VERSION] (Remove old files) Deleting empty backup folders for $SERVER_INSTANCE."
			find $BCKP_DIR/$SERVER_INSTANCE/ -type d -empty -delete
		fi
	done
	echo "[$NAME $VERSION] (Remove old files) Removal of old files complete."
}

#--------------------------

#Prints out if the server is running
script_status() {
	for SERVER_SERVICE in $(systemctl --user list-units -all --no-legend --no-pager --plain $SERVICE_NAME@*.service $SERVICE_NAME-tmpfs@*.service | awk '{print $1}'); do
		SERVER_INSTANCE=$(echo $SERVER_SERVICE | awk -F '@' '{print $2}' | awk -F '.service' '{print $1}')
		if [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "inactive" ]] && [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "enabled" ]]; then
			echo "[$NAME $VERSION] (Status) Server $SERVER_INSTANCE is not running."
		elif [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "active" ]] && [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "enabled" ]]; then
			echo "[$NAME $VERSION] (Status) Server $SERVER_INSTANCE is running."
		elif [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "failed" ]] && [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "enabled" ]]; then
			echo "[$NAME $VERSION] (Status) Server $SERVER_INSTANCE is in failed state. Please check logs."
		elif [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "activating" ]] && [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "enabled" ]]; then
			echo "[$NAME $VERSION] (Status) Server $SERVER_INSTANCE is activating. Please wait."
		elif [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "deactivating" ]] && [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "enabled" ]]; then
			echo "[$NAME $VERSION] (Status) Server $SERVER_INSTANCE is in deactivating. Please wait."
		fi
	done
	if pidof -x "$SCRIPT_PID_CHECK" -o $$ > /dev/null; then
		echo "Is another instance of the script running?: YES"
	else
		echo "Is another instance of the script running?: NO"
	fi
}

#--------------------------

#Adds a server instance to the server list file
script_add_server() {
	#Downloads game files
	script_add_server_vanilla_download() {
		if [ ! -d "$UPDATE_DIR/$1" ]; then
			mkdir -p "$UPDATE_DIR/$1"
		fi
		LATEST_VERSION=$(curl -s "https://launchermeta.mojang.com/mc/game/version_manifest.json" | jq -r '.latest.release')
		JSON_URL=$(curl -s "https://launchermeta.mojang.com/mc/game/version_manifest.json" | jq ".versions[] | select(.id==\"$LATEST_VERSION\") .url" | sed 's/"//g')
		JAR_SHA1=$(curl -s "$JSON_URL" | jq '.downloads.server .sha1' | sed 's/"//g')
		JAR_URL=$(curl -s "$JSON_URL" | jq '.downloads.server .url' | sed 's/"//g')
		echo "$LATEST_VERSION" > $UPDATE_DIR/$1/installed.version
		echo "$JAR_SHA1" > $UPDATE_DIR/$1/installed.sha1

		while [[ "$JAR_SHA1" != "$(sha1sum $SRV_DIR/$1/server.jar | awk '{print $1}')" ]]; do
			if [ -f $SRV_DIR/$1/server.jar ] ; then
				rm $SRV_DIR/$1/server.jar
			fi
			wget -O $SRV_DIR/$1/server.jar "$JAR_URL"
		done
	}

	echo "[$NAME $VERSION] (Add server instance) User adding new server instance."
	read -p "Are you sure you want to add a server instance? (y/n): " ADD_SERVER_INSTANCE_ADD
	if [[ "$ADD_SERVER_INSTANCE_ADD" =~ ^([yY][eE][sS]|[yY])$ ]]; then
		echo ""
		echo "List of current servers (your new server instance must NOT be identical to any of them!):"
		if [ ! -f $CONFIG_DIR/$SERVICE_NAME-server-list.txt ] ; then
			touch $CONFIG_DIR/$SERVICE_NAME-server-list.txt
		fi
		cat $CONFIG_DIR/$SERVICE_NAME-server-list.txt
		echo ""
		read -p "Specify your server instance (Can be a number or string. Eamples: 01, vanilla_latest or forge_1-12-2): " SERVER_INSTANCE_ADD
		echo ""
		echo "Specify your server instance type: "
		echo "1 - Vanilla"
		echo "2 - Forge"
		echo "3 - Spigot"
		read -p "Type: " SERVER_INSTANCE_ADD_TYPE
		echo ""

		read -p "Enable tmpfs for this server? (y/n): " SERVER_INSTANCE_ADD_TMPFS

		if [[ "$SERVER_INSTANCE_ADD_TYPE" == "1" ]]; then
			read -p "Do you want to download the latest server.jar from Mojang servers? (y/n): " SERVER_INSTANCE_ADD_DOWNLOAD
			read -p "Enable automatic updates from Mojang servers for this instance? (y/n): " SERVER_INSTANCE_ADD_UPDATES
		fi

		echo ""
		echo "Use latest java version?"
		echo ""
		echo "If you want to use a diffrent java version you have to have it installed on your system. This is usefull for old versions of minecraft"
		echo "and can also be changed in the server instance's environment file. You must enter the path to the java binary."
		echo ""
		echo "Example to enter: /usr/lib/jvm/java-8-openjdk/bin/java"
		echo ""
		read -p "Use default java version? (y/n): " SERVER_INSTANCE_JAVA_VER

		if [[ "$SERVER_INSTANCE_JAVA_VER" =~ ^([yY][eE][sS]|[yY])$ ]]; then
			JAVA_VER="java"
		else
			echo ""
			read -p "Enter the path to your java executable for this server instance: " JAVA_VER
		fi

		echo ""
		echo "Use default java arguments or do you want to enter your own?"
		echo ""
		echo "Default arguments: -XX:+UseG1GC -Xmx6G -Xms1G -Dsun.rmi.dgc.server.gcInterval=2147483646 -XX:+UnlockExperimentalVMOptions -XX:G1NewSizePercent=20 -XX:G1ReservePercent=20 -XX:MaxGCPauseMillis=50 -XX:G1HeapRegionSize=32M -Dfml.ignorePatchDiscrepancies=true -Dfml.ignoreInvalidMinecraftCertificates=true"
		echo ""
		read -p "Use default java arguments? (y/n): " SERVER_INSTANCE_JAVA_ARGS

		if [[ "$SERVER_INSTANCE_JAVA_ARGS" =~ ^([yY][eE][sS]|[yY])$ ]]; then
			JAVA_ARGS="-XX:+UseG1GC -Xmx6G -Xms1G -Dsun.rmi.dgc.server.gcInterval=2147483646 -XX:+UnlockExperimentalVMOptions -XX:G1NewSizePercent=20 -XX:G1ReservePercent=20 -XX:MaxGCPauseMillis=50 -XX:G1HeapRegionSize=32M -Dfml.ignorePatchDiscrepancies=true -Dfml.ignoreInvalidMinecraftCertificates=true"
		else
			echo ""
			read -p "Enter your java arguments for this server instance: " JAVA_ARGS
		fi

		echo "JAVA=$JAVA_VER" > $ENV_DIR/${SERVER_INSTANCE_ADD}.env
		echo "JAVA_ARGS=$JAVA_ARGS" >> $ENV_DIR/${SERVER_INSTANCE_ADD}.env

		if [[ "$SERVER_INSTANCE_ADD_TYPE" == "1" ]]; then
			echo "JAR_TYPE=server" >> $ENV_DIR/${SERVER_INSTANCE_ADD}.env
		elif [[ "$SERVER_INSTANCE_ADD_TYPE" == "2" ]]; then
			echo "JAR_TYPE=forge" >> $ENV_DIR/${SERVER_INSTANCE_ADD}.env
		elif [[ "$SERVER_INSTANCE_ADD_TYPE" == "3" ]]; then
			echo "JAR_TYPE=spigot" >> $ENV_DIR/${SERVER_INSTANCE_ADD}.env
		fi

		mkdir "$SRV_DIR/$SERVER_INSTANCE_ADD"

		if [[ "$SERVER_INSTANCE_ADD_TMPFS" =~ ^([yY][eE][sS]|[yY])$ ]]; then
			if [[ "$SERVER_INSTANCE_ADD_TYPE" == "1" ]]; then
				if [[ "$SERVER_INSTANCE_ADD_DOWNLOAD" =~ ^([yY][eE][sS]|[yY])$ ]]; then
					script_add_server_vanilla_download $SERVER_INSTANCE_ADD
				fi
				if [[ "$SERVER_INSTANCE_ADD_UPDATES" =~ ^([yY][eE][sS]|[yY])$ ]]; then
					echo "$SERVICE_NAME-tmpfs@$SERVER_INSTANCE_ADD.service" >> $CONFIG_DIR/$SERVICE_NAME-server-update-list.txt
				fi
			fi
			echo "$SERVICE_NAME-tmpfs@$SERVER_INSTANCE_ADD.service" >> $CONFIG_DIR/$SERVICE_NAME-server-list.txt
			systemctl --user enable --now $SERVICE_NAME-mkdir-tmpfs@$SERVER_INSTANCE_ADD.service
			systemctl --user enable $SERVICE_NAME-tmpfs@$SERVER_INSTANCE_ADD.service
		else
			if [[ "$SERVER_INSTANCE_ADD_TYPE" == "1" ]]; then
				if [[ "$SERVER_INSTANCE_ADD_DOWNLOAD" =~ ^([yY][eE][sS]|[yY])$ ]]; then
					script_add_server_vanilla_download $SERVER_INSTANCE_ADD
				fi
				if [[ "$SERVER_INSTANCE_ADD_UPDATES" =~ ^([yY][eE][sS]|[yY])$ ]]; then
					echo "$SERVICE_NAME@$SERVER_INSTANCE_ADD.service" >> $CONFIG_DIR/$SERVICE_NAME-server-update-list.txt
				fi
			fi
			echo "$SERVICE_NAME@$SERVER_INSTANCE_ADD.service" >> $CONFIG_DIR/$SERVICE_NAME-server-list.txt
			systemctl --user enable $SERVICE_NAME@$SERVER_INSTANCE_ADD.service
		fi
		systemctl --user daemon-reload
		echo "eula=true" > $SRV_DIR/$SERVER_INSTANCE_ADD/eula.txt
		if [ -f "$SRV_DIR/$SERVER_INSTANCE_ADD/server.jar" ] || [ -f "$(ls -v $SRV_DIR/$SERVER_INSTANCE_ADD | grep -i "forge" | grep -i ".jar" | head -n 1)" ] || [ -f "$(ls -v $SRV_DIR/$SERVER_INSTANCE_ADD | grep -i "spigot" | grep -i ".jar" | head -n 1)" ]; then
			read -p "Server instance $SERVER_INSTANCE_ADD added successfully. Do you want to start it? (y/n): " START_SERVER_INSTANCE_ADD
			if [[ "$START_SERVER_INSTANCE_ADD" =~ ^([yY][eE][sS]|[yY])$ ]]; then
				if [[ "$SERVER_INSTANCE_ADD_TMPFS" =~ ^([yY][eE][sS]|[yY])$ ]]; then
					systemctl --user start $SERVICE_NAME-tmpfs@$SERVER_INSTANCE_ADD.service
				else
					systemctl --user start $SERVICE_NAME@$SERVER_INSTANCE_ADD.service
				fi
			fi
		else
			echo "No supported jar file found. Copy your server files to $SRV_DIR/$SERVER_INSTANCE_ADD and start the server."
		fi
		echo "[$NAME $VERSION] (Add server instance) Server instance $SERVER_INSTANCE_ADD successfully added."
	else
		echo "[$NAME $VERSION] (Add server instance) User canceled adding new server instance."
	fi
}

#--------------------------

#Removes a server instance from the server list file
script_remove_server() {
	echo "[$NAME $VERSION] (Remove server instance) User started removal of server instance."
	read -p "Are you sure you want to remove a server instance? (y/n): " REMOVE_SERVER_INSTANCE
	if [[ "$REMOVE_SERVER_INSTANCE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
		for SERVER_SERVICE in $(cat $CONFIG_DIR/$SERVICE_NAME-server-list.txt); do
			SERVER_INSTANCE_LIST=("$SERVER_SERVICE" "${SERVER_INSTANCE_LIST[@]}")
		done
		SERVER_INSTANCE_LIST=("Cancel" "${SERVER_INSTANCE_LIST[@]}")
		select SERVER_INSTANCE in "${SERVER_INSTANCE_LIST[@]}"; do
			SERVER_INSTANCE_REMOVE=$(echo $SERVER_SERVICE | awk -F '@' '{print $2}' | awk -F '.service' '{print $1}')
			if [[ "$SERVER_INSTANCE_REMOVE" == "Cancel" ]]; then
				echo "[$NAME $VERSION] (Remove server instance) User canceled removal of server instance."
				break
			fi
			sed -e "s/$SERVER_INSTANCE//g" -i $CONFIG_DIR/$SERVICE_NAME-server-list.txt
			sed '/^$/d' -i $CONFIG_DIR/$SERVICE_NAME-server-list.txt
			sed -e "s/$SERVER_INSTANCE//g" -i $CONFIG_DIR/$SERVICE_NAME-server-update-list.txt
			sed '/^$/d' -i $CONFIG_DIR/$SERVICE_NAME-server-update-list.txt
			if [ -d "/srv/$SERVICE_NAME/.config/systemd/user/$SERVER_INSTANCE.d" ] ; then
				rm -rf /srv/$SERVICE_NAME/.config/systemd/user/$SERVER_INSTANCE.d
			fi
			if [[ "$(systemctl --user show -p UnitFileState --value $SERVICE_NAME-mkdir-tmpfs@$SERVER_INSTANCE_REMOVE.service)" == "enabled" ]]; then
				systemctl --user disable $SERVICE_NAME-mkdir-tmpfs@$SERVER_INSTANCE_REMOVE.service
			fi
			systemctl --user disable $SERVER_INSTANCE
			read -p "Server instance $SERVER_INSTANCE removed successfully. Do you want to stop it? (y/n): " STOP_SERVER_INSTANCE
			if [[ "$STOP_SERVER_INSTANCE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
				systemctl --user stop $SERVER_INSTANCE
				read -p "Delete the server folder for $SERVER_INSTANCE_REMOVE? (y/n): " DELETE_SERVER_INSTANCE
				if [[ "$DELETE_SERVER_INSTANCE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
					rm -rf $SRV_DIR/$SERVER_INSTANCE_REMOVE
				fi
			fi
			read -p "Delete the backup folder for $SERVER_INSTANCE_REMOVE? (y/n): " DELETE_SERVER_BACKUP
			if [[ "$DELETE_SERVER_BACKUP" =~ ^([yY][eE][sS]|[yY])$ ]]; then
				rm -rf $BCKP_DIR/$SERVER_INSTANCE_REMOVE
			fi
			read -p "Delete the environment file for $SERVER_INSTANCE_REMOVE? (y/n): " DELETE_SERVER_ENV_FILE
			if [[ "$DELETE_SERVER_ENV_FILE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
				rm $ENV_DIR/${SERVER_INSTANCE_REMOVE}.env
			fi
			echo "[$NAME $VERSION] (Remove server instance) Server instance $SERVER_INSTANCE_REMOVE successfully removed."
			break
		done
	else
		echo "[$NAME $VERSION] (Remove server instance) User canceled removal of server instance."
	fi
}

#--------------------------

#Disable all script services
script_disable_services() {
	for SERVER_SERVICE in $(systemctl --user list-units -all --no-legend --no-pager --plain $SERVICE_NAME@*.service $SERVICE_NAME-tmpfs@*.service | awk '{print $1}'); do
		SERVER_INSTANCE=$(echo $SERVER_SERVICE | awk -F '@' '{print $2}' | awk -F '.service' '{print $1}')
		if [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "enabled" ]]; then
			systemctl --user disable $SERVER_SERVICE
			if [[ "$(systemctl --user show -p UnitFileState --value $SERVICE_NAME-mkdir-tmpfs@$SERVER_INSTANCE.service)" == "enabled" ]]; then
				systemctl --user disable $SERVICE_NAME-mkdir-tmpfs@$SERVER_INSTANCE.service
			fi
		fi
	done
	if [[ "$(systemctl --user show -p UnitFileState --value $SERVICE_NAME-timer-1.timer)" == "enabled" ]]; then
		systemctl --user disable --now $SERVICE_NAME-timer-1.timer
	fi
	if [[ "$(systemctl --user show -p UnitFileState --value $SERVICE_NAME-timer-2.timer)" == "enabled" ]]; then
		systemctl --user disable --now $SERVICE_NAME-timer-2.timer
	fi
	echo "[$NAME $VERSION] (Disable services) Services successfully disabled."
}

#--------------------------

#Disables all script services, available to the user
script_disable_services_manual() {
	echo "[$NAME $VERSION] (Disable services) WARNING: This will disable all script services. The server will be disabled."
	read -p "Are you sure you want to disable all services? (y/n): " DISABLE_SCRIPT_SERVICES
	if [[ "$DISABLE_SCRIPT_SERVICES" =~ ^([yY][eE][sS]|[yY])$ ]]; then
		script_disable_services
	elif [[ "$DISABLE_SCRIPT_SERVICES" =~ ^([nN][oO]|[nN])$ ]]; then
		echo "[$NAME $VERSION] (Disable services) Disable services canceled."
	fi
}

#--------------------------

# Enable script services by reading the configuration file
script_enable_services() {
	for SERVER_SERVICE in $(cat $CONFIG_DIR/$SERVICE_NAME-server-list.txt); do
		SERVER_INSTANCE=$(echo $SERVER_SERVICE | awk -F '@' '{print $2}' | awk -F '.service' '{print $1}')
		if [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "disabled" ]]; then
			systemctl --user enable $SERVER_SERVICE
		fi
		if [[ "$(systemctl --user show -p UnitFileState --value $SERVICE_NAME-tmpfs@$SERVER_INSTANCE)" == "disabled" ]];then
			systemctl --user enable $SERVICE_NAME-mkdir-tmpfs@$SERVER_INSTANCE.service
		fi
	done
	if [[ "$(systemctl --user show -p UnitFileState --value $SERVICE_NAME-timer-1.timer)" == "disabled" ]]; then
		systemctl --user enable --now $SERVICE_NAME-timer-1.timer
	fi
	if [[ "$(systemctl --user show -p UnitFileState --value $SERVICE_NAME-timer-2.timer)" == "disabled" ]]; then
		systemctl --user enable --now $SERVICE_NAME-timer-2.timer
	fi
	echo "[$NAME $VERSION] (Enable services) Services successfully Enabled."
}

#--------------------------

# Enable script services by reading the configuration file, available to the user
script_enable_services_manual() {
	echo "[$NAME $VERSION] (Enable services) This will enable all script services. All added servers will be enabled."
	read -p "Are you sure you want to enable all services? (y/n): " ENABLE_SCRIPT_SERVICES
	if [[ "$ENABLE_SCRIPT_SERVICES" =~ ^([yY][eE][sS]|[yY])$ ]]; then
		script_enable_services
	elif [[ "$ENABLE_SCRIPT_SERVICES" =~ ^([nN][oO]|[nN])$ ]]; then
		echo "[$NAME $VERSION] (Enable services) Enable services canceled."
	fi
}

#--------------------------

#Disables all script services an re-enables them by reading the configuration file
script_reload_services() {
	echo "[$NAME $VERSION] (Reload services) This will reload all script services."
	read -p "Are you sure you want to reload all services? (y/n): " RELOAD_SCRIPT_SERVICES
	if [[ "$RELOAD_SCRIPT_SERVICES" =~ ^([yY][eE][sS]|[yY])$ ]]; then
		script_disable_services
		systemctl --user daemon-reload
		systemctl --user reset-failed
		script_enable_services
		echo "[$NAME $VERSION] (Reload services) Reload services complete."
	elif [[ "$RELOAD_SCRIPT_SERVICES" =~ ^([nN][oO]|[nN])$ ]]; then
		echo "[$NAME $VERSION] (Reload services) Reload services canceled."
	fi
}

#--------------------------

#Sync server files from ramdisk to hdd/ssd
script_sync() {
	for SERVER_SERVICE in $(systemctl --user list-units -all --no-legend --no-pager --plain $SERVICE_NAME-tmpfs@*.service | awk '{print $1}'); do
		SERVER_INSTANCE=$(echo $SERVER_SERVICE | awk -F '@' '{print $2}' | awk -F '.service' '{print $1}')
		if [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" != "active" ]] && [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "enabled" ]]; then
			echo "[$NAME $VERSION] (Sync) Server $SERVER_INSTANCE is not running."
		elif [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "active" ]] && [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "enabled" ]]; then
			echo "[$NAME $VERSION] (Sync) Sync from tmpfs to disk for server $SERVER_INSTANCE has been initiated."
			/usr/bin/tmux -L $SERVICE_NAME-$SERVER_INSTANCE-tmux.sock send-keys -t $NAME.0 "say Sync from tmpfs to disk has been initiated." ENTER
			rsync -aAX --info=progress2 $TMPFS_DIR/$SERVER_INSTANCE/ $SRV_DIR/$SERVER_INSTANCE
			/usr/bin/tmux -L $SERVICE_NAME-$SERVER_INSTANCE-tmux.sock send-keys -t $NAME.0 "say Sync from tmpfs to disk has been completed." ENTER
			sleep 1
			echo "[$NAME $VERSION] (Sync) Sync from tmpfs to disk for server $SERVER_INSTANCE has been completed."
		fi
	done
}

#--------------------------

#Checks the space occupied on the tmpfs partition and if it's over the user designated value, shuts down tmpfs servers
script_tmpfs_space_check() {
	CURRENT_TMPFS_SPACE=$(df -H | grep "$TMPFS_DIR" | awk '{print $5}' | cut -d'%' -f1)
	if [ $CURRENT_TMPFS_SPACE -ge $TMPFS_SPACE ] ; then
		if [[ "$DISCORD_TMPFS_SPACE" == "1" ]]; then
			script_discord_message "$DISCORD_COLOR_TMPFS_SPACE" "The tmpfs partition is $CURRENT_TMPFS_SPACE percent filled. Automatic shutdown of tmpfs servers has been initiated."
		fi
		if [[ "$EMAIL_TMPFS_SPACE" == "1" ]]; then
			script_email_message "$NAME-$1" "Notification: Tmpfs running out of space" "The tmpfs partition is $CURRENT_TMPFS_SPACE percent filled. Automatic shutdown of tmpfs servers has been initiated."
		fi
		echo "[$NAME $VERSION] (Tmpfs space check) The tmpfs partition is at $CURRENT_TMPFS_SPACE percent filled.  Automatic shutdown of tmpfs servers has been initiated."
		for SERVER_SERVICE in $(systemctl --user list-units -all --no-legend --no-pager --plain $SERVICE_NAME-tmpfs@*.service | awk '{print $1}'); do
			SERVER_INSTANCE=$(echo $SERVER_SERVICE | awk -F '@' '{print $2}' | awk -F '.service' '{print $1}')
			if [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "active" ]] && [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "enabled" ]]; then
				script_stop $SERVER_SERVICE
			fi
		done
		echo "[$NAME $VERSION] (Tmpfs space check) Shutdown of tmpfs servers complete."
	fi
}

#--------------------------

#Pre-start functions to be called by the systemd service
script_prestart() {
	if [[ "$DISCORD_START" == "1" ]]; then
		script_discord_message "$DISCORD_COLOR_PRESTART" "Server startup for $1 was initialized."
	fi
	if [[ "$EMAIL_START" == "1" ]]; then
		script_email_message "$NAME-$1" "Notification: Server startup $1" "Server startup for $1 was initialized at $(date +"%d.%m.%Y %H:%M:%S")"
	fi
	echo "[$NAME $VERSION] (Start) Server startup for $1 was initialized."

	if [[ "$2" == "tmpfs" ]]; then
		echo "[$NAME $VERSION] (Start) Sync from disk to tmpfs for $1 has been initiated."
		if [ -d "$SRV_DIR/$1" ]; then
			rsync -aAX --info=progress2 $SRV_DIR/$1/ $TMPFS_DIR/$1
		fi
		echo "[$NAME $VERSION] (Start) Sync from disk to tmpfs for $1 complete."
	fi
}

#--------------------------

#Post-start functions to be called by the systemd service
script_poststart() {
	if [[ "$DISCORD_START" == "1" ]]; then
		script_discord_message "$DISCORD_COLOR_POSTSTART" "Server startup for $1 complete."
	fi
	if [[ "$EMAIL_START" == "1" ]]; then
		script_email_message "$NAME-$1" "Notification: Server startup $1" "Server startup for $1 was completed at $(date +"%d.%m.%Y %H:%M:%S")"
	fi
	echo "[$NAME $VERSION] (Start) Server startup for $1 complete."
}

#--------------------------

#Pre-stop functions to be called by the systemd service
script_prestop() {
	if [[ "$DISCORD_STOP" == "1" ]]; then
		script_discord_message "$DISCORD_COLOR_PRESTOP" "Server shutdown for $1 was initialized."
	fi
	if [[ "$EMAIL_STOP" == "1" ]]; then
		script_email_message "$NAME-$1" "Notification: Server shutdown $1" "Server shutdown was initiated at $(date +"%d.%m.%Y %H:%M:%S")"
	fi
	echo "[$NAME $VERSION] (Stop) Server shutdown for $1 was initialized."
}

#--------------------------

#Post-stop functions to be called by the systemd service
script_poststop() {
	#Check if the server is still running, if it is wait for it to stop.
	while true; do
		tmux -L $SERVICE_NAME-$1-tmux.sock has-session -t $NAME 2>/dev/null
		if [ $? -eq 1 ]; then
			break
		fi
		sleep 1
	done

	if [[ "$2" == "tmpfs" ]]; then
		echo "[$NAME $VERSION] (Start) Sync from tmpfs to disk for $1 has been initiated."
		if [ -d "$TMPFS_DIR/$1" ]; then
			rsync -aAX --info=progress2 $TMPFS_DIR/$1/ $SRV_DIR/$1
		fi
		echo "[$NAME $VERSION] (Start) Sync from tmpfs to disk for $1 complete."
	fi

	if [ -f "/tmp/$SERVICE_NAME-$1-tmux.log" ]; then
		rm /tmp/$SERVICE_NAME-$1-tmux.log
	fi

	if [ -f "/tmp/$SERVICE_NAME-$1-tmux.conf" ]; then
		rm /tmp/$SERVICE_NAME-$1-tmux.conf
	fi

	if [[ "$DISCORD_STOP" == "1" ]]; then
		script_discord_message "$DISCORD_COLOR_POSTSTOP" "Server shutdown for $1 complete."
	fi
	if [[ "$EMAIL_STOP" == "1" ]]; then
		script_email_message "$NAME-$1" "Notification: Server shutdown $1" "Server shutdown was complete at $(date +"%d.%m.%Y %H:%M:%S")"
	fi
	echo "[$NAME $VERSION] (Stop) Server shutdown for $1 complete."
}

#--------------------------

#Start the server
script_start() {
	#Loop until the server is active and output the state of it
	script_start_loop() {
		SERVER_INSTANCE_LOOP=$(echo $1 | awk -F '@' '{print $2}' | awk -F '.service' '{print $1}')
		while [[ "$(systemctl --user show -p ActiveState --value $1)" == "activating" ]] && [[ "$(systemctl --user show -p UnitFileState --value $1)" == "enabled" ]]; do
			echo "[$NAME $VERSION] (Start) Server $SERVER_INSTANCE_LOOP is activating. Please wait..."
			sleep 1
		done
		if [[ "$(systemctl --user show -p ActiveState --value $1)" == "active" ]] && [[ "$(systemctl --user show -p UnitFileState --value $1)" == "enabled" ]]; then
			echo "[$NAME $VERSION] (Start) Server $SERVER_INSTANCE_LOOP has been successfully activated."
			sleep 1
		elif [[ "$(systemctl --user show -p ActiveState --value $1)" == "failed" ]] && [[ "$(systemctl --user show -p UnitFileState --value $1)" == "enabled" ]]; then
			echo "[$NAME $VERSION] (Start) Server $SERVER_INSTANCE_LOOP failed to activate. See systemctl --user status $1 for details."
			sleep 1
		fi
	}

	if [[ -z "$1" ]] || [[ "$1" == "ignore" ]]; then
		for SERVER_SERVICE in $(systemctl --user list-units -all --no-legend --no-pager --plain $SERVICE_NAME@*.service $SERVICE_NAME-tmpfs@*.service | awk '{print $1}'); do
			SERVER_INSTANCE=$(echo $SERVER_SERVICE | awk -F '@' '{print $2}' | awk -F '.service' '{print $1}')
			if [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "inactive" ]] && [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "enabled" ]]; then
				echo "[$NAME $VERSION] (Start) Server $SERVER_INSTANCE start initialized."
				systemctl --user start $SERVER_SERVICE
				script_start_loop $SERVER_SERVICE
			elif [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "active" ]] && [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "enabled" ]]; then
				echo "[$NAME $VERSION] (Start) Server $SERVER_INSTANCE is already running."
			elif [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "failed" ]] && [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "enabled" ]]; then
				echo "[$NAME $VERSION] (Start) Server $SERVER_INSTANCE is in failed state. See systemctl --user status $SERVER_SERVICE for details."
				if [[ "$1" == "ignore" ]]; then
					systemctl --user start $SERVER_SERVICE
					script_start_loop $SERVER_SERVICE
				else
					read -p "Do you still want to start the server? (y/n): " FORCE_START
					if [[ "$FORCE_START" =~ ^([yY][eE][sS]|[yY])$ ]]; then
						systemctl --user start $SERVER_SERVICE
						script_start_loop $SERVER_SERVICE
					fi
				fi
			fi
		done
	else
		for SERVER_SERVICE in $(systemctl --user list-units -all --no-legend --no-pager --plain $SERVICE_NAME@$1.service $SERVICE_NAME-tmpfs@$1.service | awk '{print $1}'); do
			SERVER_INSTANCE=$(echo $SERVER_SERVICE | awk -F '@' '{print $2}' | awk -F '.service' '{print $1}')
			if [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "inactive" ]] && [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "enabled" ]]; then
				echo "[$NAME $VERSION] (Start) Server $1 start initialized."
				systemctl --user start $SERVER_SERVICE
				script_start_loop $SERVER_SERVICE
			elif [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "active" ]] && [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "enabled" ]]; then
				echo "[$NAME $VERSION] (Start) Server $1 is already running."
			elif [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "failed" ]] && [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "enabled" ]]; then
				echo "[$NAME $VERSION] (Start) Server $1 is in failed state. See systemctl --user status $SERVER_SERVICE for details."
				if [[ "$2" == "ignore" ]]; then
					systemctl --user start $SERVER_SERVICE
					script_start_loop $SERVER_SERVICE
				else
					read -p "Do you still want to start the server? (y/n): " FORCE_START
					if [[ "$FORCE_START" =~ ^([yY][eE][sS]|[yY])$ ]]; then
						systemctl --user start $SERVER_SERVICE
						script_start_loop $SERVER_SERVICE
					fi
				fi
			fi
		done
	fi
}

#--------------------------

#Stop the server
script_stop() {
	#Loop until the server is inactive and output the state of it
	script_stop_loop() {
		SERVER_INSTANCE_LOOP=$(echo $1 | awk -F '@' '{print $2}' | awk -F '.service' '{print $1}')
		while [[ "$(systemctl --user show -p ActiveState --value $1)" == "deactivating" ]]; do
			echo "[$NAME $VERSION] (Stop) Server $SERVER_INSTANCE_LOOP is deactivating. Please wait..."
			sleep 1
		done
		echo "[$NAME $VERSION] (Stop) Server $SERVER_INSTANCE_LOOP is deactivated."
	}

	if [ -z "$1" ]; then
		for SERVER_SERVICE in $(systemctl --user list-units -all --no-legend --no-pager --plain $SERVICE_NAME@*.service $SERVICE_NAME-tmpfs@*.service | awk '{print $1}'); do
			SERVER_INSTANCE=$(echo $SERVER_SERVICE | awk -F '@' '{print $2}' | awk -F '.service' '{print $1}')
			if [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "inactive" ]] && [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "enabled" ]]; then
				echo "[$NAME $VERSION] (Stop) Server $SERVER_INSTANCE is not running."
			elif [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "failed" ]] && [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "enabled" ]]; then
				echo "[$NAME $VERSION] (Stop) Server $SERVER_INSTANCE is in failed state. Please check logs."
			elif [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "active" ]] && [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "enabled" ]]; then
				echo "[$NAME $VERSION] (Stop) Server $SERVER_INSTANCE shutdown in progress."
				systemctl --user stop $SERVER_SERVICE
				script_stop_loop $SERVER_SERVICE
			fi
		done
	else
		for SERVER_SERVICE in $(systemctl --user list-units -all --no-legend --no-pager --plain $SERVICE_NAME@$1.service $SERVICE_NAME-tmpfs@$1.service | awk '{print $1}'); do
			SERVER_INSTANCE=$(echo $SERVER_SERVICE | awk -F '@' '{print $2}' | awk -F '.service' '{print $1}')
			if [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "inactive" ]] && [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "enabled" ]]; then
				echo "[$NAME $VERSION] (Stop) Server $SERVER_INSTANCE is not running."
			elif [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "failed" ]] && [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "enabled" ]]; then
				echo "[$NAME $VERSION] (Stop) Server $SERVER_INSTANCE is in failed state. Please check logs."
			elif [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "active" ]] && [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "enabled" ]]; then
				echo "[$NAME $VERSION] (Stop) Server $SERVER_INSTANCE shutdown in progress."
				systemctl --user stop $SERVER_SERVICE
				script_stop_loop $SERVER_SERVICE
			fi
		done
	fi
}

#--------------------------

#Restart the server
script_restart() {
	if [ -z "$1" ]; then
		for SERVER_SERVICE in $(systemctl --user list-units -all --no-legend --no-pager --plain $SERVICE_NAME@*.service $SERVICE_NAME-tmpfs@*.service | awk '{print $1}'); do
			SERVER_INSTANCE=$(echo $SERVER_SERVICE | awk -F '@' '{print $2}' | awk -F '.service' '{print $1}')
			if [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "inactive" ]] && [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "enabled" ]]; then
				echo "[$NAME $VERSION] (Restart) Server $SERVER_INSTANCE is not running. Execute $SERVICE_NAME-script start to start the server."
			elif [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "activating" ]] && [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "enabled" ]]; then
				echo "[$NAME $VERSION] (Restart) Server $SERVER_INSTANCE is activating. Aborting restart."
			elif [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "deactivating" ]] && [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "enabled" ]]; then
				echo "[$NAME $VERSION] (Restart) Server $SERVER_INSTANCE is in deactivating. Aborting restart."
			elif [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "active" ]] && [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "enabled" ]]; then
				echo "[$NAME $VERSION] (Restart) Server $SERVER_INSTANCE is going to restart in 15-30 seconds, please wait..."
				sleep 1
				script_stop $SERVER_INSTANCE
				sleep 1
				script_start $SERVER_INSTANCE
				sleep 1
			fi
		done
	else
		for SERVER_SERVICE in $(systemctl --user list-units -all --no-legend --no-pager --plain $SERVICE_NAME@$1.service $SERVICE_NAME-tmpfs@$1.service | awk '{print $1}'); do
			if [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "inactive" ]] && [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "enabled" ]]; then
				echo "[$NAME $VERSION] (Restart) Server $SERVER_INSTANCE is not running. Execute $SERVICE_NAME-script start to start the server."
			elif [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "activating" ]] && [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "enabled" ]]; then
				echo "[$NAME $VERSION] (Restart) Server $SERVER_INSTANCE is activating. Aborting restart."
			elif [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "deactivating" ]] && [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "enabled" ]]; then
				echo "[$NAME $VERSION] (Restart) Server $SERVER_INSTANCE is in deactivating. Aborting restart."
			elif [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "active" ]] && [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "enabled" ]]; then
				echo "[$NAME $VERSION] (Restart) Server $SERVER_INSTANCE is going to restart in 15-30 seconds, please wait..."
				sleep 1
				script_stop $SERVER_INSTANCE
				sleep 1
				script_start $SERVER_INSTANCE
				sleep 1
			fi
		done
	fi
}

#--------------------------

#Systemd service sends email if email notifications for crashes enabled
script_send_notification_crash() {
	script_logs
	CRASH_TIME=$(date +"%Y-%m-%d_%H-%M")
	if [ ! -d "$LOG_STRUCTURE/Server-$1-crash_$CRASH_TIME" ]; then
		mkdir -p "$LOG_STRUCTURE/Server-$1-crash_$CRASH_TIME"
	fi

	if [[ "$(systemctl --user show -p UnitFileState --value $SERVICE_NAME-tmpfs@$1.service)" == "enabled" ]]; then
		systemctl --user status $SERVICE_NAME-tmpfs@$1.service > $LOG_STRUCTURE/Server-$1-crash_$CRASH_TIME/service_log.txt
		journalctl --user -u $SERVICE_NAME-tmpfs@$1.service > $LOG_STRUCTURE/Server-$1-crash_$CRASH_TIME/journal_log.txt
		find "$TMPFS_DIR/$1/logs/" -maxdepth 1 -type f \( ! -iname "*.gz" \) -mmin -30 -exec zip $LOG_STRUCTURE/Server-$1-crash_$CRASH_TIME/game_logs.zip -j {} +
	elif [[ "$(systemctl --user show -p UnitFileState --value $SERVICE_NAME@$1.service)" == "enabled" ]]; then
		systemctl --user status $SERVICE_NAME@$1.service > $LOG_STRUCTURE/Server-$1-crash_$CRASH_TIME/service_log.txt
		journalctl --user -u $SERVICE_NAME@$1.service > $LOG_STRUCTURE/Server-$1-crash_$CRASH_TIME/journal_log.txt
		find "$SRV_DIR/$1/logs/" -maxdepth 1 -type f \( ! -iname "*.gz" \) -mmin -30 -exec zip $LOG_STRUCTURE/Server-$1-crash_$CRASH_TIME/game_logs.zip -j {} +
	fi
	journalctl --user -u $SERVICE_NAME-timer-1.service > $LOG_STRUCTURE/Server-$1-crash_$CRASH_TIME/journal_log_timer-1.txt
	journalctl --user -u $SERVICE_NAME-timer-2.service > $LOG_STRUCTURE/Server-$1-crash_$CRASH_TIME/journal_log_timer-2.txt

	zip -j $LOG_STRUCTURE/Server-$1-crash_$CRASH_TIME/service_logs.zip $LOG_STRUCTURE/Server-$1-crash_$CRASH_TIME/service_log.txt $LOG_STRUCTURE/Server-$1-crash_$CRASH_TIME/journal_log_timer-1.txt $LOG_STRUCTURE/Server-$1-crash_$CRASH_TIME/journal_log_timer-2.txt
	rm $LOG_STRUCTURE/Server-$1-crash_$CRASH_TIME/service_log.txt $LOG_STRUCTURE/Server-$1-crash_$CRASH_TIME/journal_log_timer-1.txt $LOG_STRUCTURE/Server-$1-crash_$CRASH_TIME/journal_log_timer-2.txt

	if [[ "$EMAIL_CRASH" == "1" ]]; then
		mail -a $LOG_STRUCTURE/Server-$1-crash_$CRASH_TIME/service_logs.zip -a $LOG_STRUCTURE/Server-$1-crash_$CRASH_TIME/game_logs.zip -r "$EMAIL_SENDER ($NAME $SERVICE_NAME)" -s "Notification: Server $1 crash" $EMAIL_RECIPIENT <<- EOF
		The $NAME server $1 crashed 3 times in the last 5 minutes. Automatic restart is disabled and the server is inactive. Please check the logs for more information.

		Attachment contents:
		service_logs.zip - Logs from the systemd service
		game_logs.zip - Logs from the game
		EOF
	fi

	if [[ "$DISCORD_CRASH" == "1" ]]; then
		script_discord_message "$DISCORD_COLOR_CRASH" "Server $1 crashed 3 times in the last 5 minutes.\nAutomatic restart is disabled and the server is inactive.\n\nPlease review your logs located in $LOG_STRUCTURE/Server-$1-crash_$CRASH_TIME."
	fi
	echo "[$NAME $VERSION] (Crash) Server $1 crashed. Please review your logs located in $LOG_STRUCTURE/Server-$1-crash_$CRASH_TIME."
}

#--------------------------

#Creates a backup of the server
script_backup() {
	#If there is not a folder for today, create one
	script_backup_create_folder() {
		if [ ! -d "$BCKP_DIR/$1/$BCKP_STRUCTURE" ]; then
			mkdir -p "$BCKP_DIR/$1/$BCKP_STRUCTURE"
		fi
	}

	#Backup source to destination
	echo "[$NAME $VERSION] (Backup) Backup has been initiated."
	for SERVER_SERVICE in $(systemctl --user list-units -all --no-legend --no-pager --plain $SERVICE_NAME-tmpfs@*.service | awk '{print $1}'); do
		SERVER_INSTANCE=$(echo $SERVER_SERVICE | awk -F '@' '{print $2}' | awk -F '.service' '{print $1}')
		if [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" != "active" ]] && [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "enabled" ]]; then
			echo "[$NAME $VERSION] (Autobackup) Server $SERVER_INSTANCE is not running."
		elif [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "active" ]] && [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "enabled" ]]; then
			/usr/bin/tmux -L $SERVICE_NAME-$SERVER_INSTANCE-tmux.sock send-keys -t $NAME.0 "say Server backup in progress." ENTER
			script_backup_create_folder $SERVER_INSTANCE
			cd "$TMPFS_DIR/$SERVER_INSTANCE"
			tar -cpvzf $BCKP_DIR/$SERVER_INSTANCE/$BCKP_STRUCTURE/$(date +"%Y%m%d%H%M")_$SERVER_INSTANCE.tar.gz $TMPFS_DIR/$SERVER_INSTANCE/
			/usr/bin/tmux -L $SERVICE_NAME-$SERVER_INSTANCE-tmux.sock send-keys -t $NAME.0 "say Server backup complete." ENTER
		fi
	done
	for SERVER_SERVICE in $(systemctl --user list-units -all --no-legend --no-pager --plain $SERVICE_NAME@*.service | awk '{print $1}'); do
		SERVER_INSTANCE=$(echo $SERVER_SERVICE | awk -F '@' '{print $2}' | awk -F '.service' '{print $1}')
		if [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" != "active" ]] && [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "enabled" ]]; then
			echo "[$NAME $VERSION] (Autobackup) Server $SERVER_INSTANCE is not running."
		elif [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "active" ]] && [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "enabled" ]]; then
			/usr/bin/tmux -L $SERVICE_NAME-$SERVER_INSTANCE-tmux.sock send-keys -t $NAME.0 "say Server backup in progress." ENTER
			script_backup_create_folder $SERVER_INSTANCE
			cd "$SRV_DIR/$SERVER_INSTANCE"
			tar -cpvzf $BCKP_DIR/$SERVER_INSTANCE/$BCKP_STRUCTURE/$(date +"%Y%m%d%H%M")_$SERVER_INSTANCE.tar.gz $SRV_DIR/$SERVER_INSTANCE/
			/usr/bin/tmux -L $SERVICE_NAME-$SERVER_INSTANCE-tmux.sock send-keys -t $NAME.0 "say Server backup complete." ENTER
		fi
	done
	echo "[$NAME $VERSION] (Backup) Backup complete."
}

#--------------------------

#Check for updates. If there are updates available, shut down the server, update it and restart it.
script_update() {
	for SERVER_SERVICE in $(cat $CONFIG_DIR/$SERVICE_NAME-server-update-list.txt); do
		SERVER_INSTANCE=$(echo $SERVER_SERVICE | awk -F '@' '{print $2}' | awk -F '.service' '{print $1}')
		echo "[$NAME $VERSION] (Update) Initializing update check for server $SERVER_INSTANCE."

		if [ ! -d "$UPDATE_DIR/$SERVER_INSTANCE" ]; then
			mkdir -p "$UPDATE_DIR/$SERVER_INSTANCE"
		fi

		if [ ! -f $UPDATE_DIR/$SERVER_INSTANCE/installed.version ] ; then
			touch $UPDATE_DIR/$SERVER_INSTANCE/installed.version
			echo "0" > $UPDATE_DIR/$SERVER_INSTANCE/installed.version
		fi

		if [ ! -f $UPDATE_DIR/$SERVER_INSTANCE/installed.sha1 ] ; then
			touch $UPDATE_DIR/$SERVER_INSTANCE/installed.sha1
			echo "0" > $UPDATE_DIR/$SERVER_INSTANCE/installed.sha1
		fi

		echo "[$NAME $VERSION] (Update) Connecting to mojang servers."

		LATEST_VERSION=$(curl -s "https://launchermeta.mojang.com/mc/game/version_manifest.json" | jq -r '.latest.release')
		JSON_URL=$(curl -s "https://launchermeta.mojang.com/mc/game/version_manifest.json" | jq ".versions[] | select(.id==\"$LATEST_VERSION\") .url" | sed 's/"//g')
		JAR_SHA1=$(curl -s "$JSON_URL" | jq '.downloads.server .sha1' | sed 's/"//g')
		JAR_URL=$(curl -s "$JSON_URL" | jq '.downloads.server .url' | sed 's/"//g')

		echo "[$NAME $VERSION] (Update) Received application info data."

		INSTALLED_VERSION=$(cat $UPDATE_DIR/$SERVER_INSTANCE/installed.version)
		INSTALLED_SHA1=$(cat $UPDATE_DIR/$SERVER_INSTANCE/installed.sha1)

		if [[ "$JAR_SHA1" != "$INSTALLED_SHA1" ]]; then
			echo "[$NAME $VERSION] (Update) New update for server $SERVER_INSTANCE detected."
			echo "[$NAME $VERSION] (Update) Server $SERVER_INSTANCE installed version: $INSTALLED_VERSION, SHA1: $INSTALLED_SHA1"
			echo "[$NAME $VERSION] (Update) Server $SERVER_INSTANCE available version: $LATEST_VERSION, SHA1: $JAR_SHA1"

			if [[ "$DISCORD_UPDATE" == "1" ]]; then
				script_discord_message "$DISCORD_COLOR_UPDATE" "New update detected. Installing update."
			fi

			if [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "active" ]] && [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "enabled" ]]; then
				WAS_ACTIVE="1"
				script_stop $SERVER_INSTANCE
			fi

			if [[ "$(echo $SERVER_SERVICE | awk -F '@' '{print $1}')" == "$SERVICE_NAME-tmpfs" ]]; then
				rm -rf $TMPFS_DIR/$SERVER_INSTANCE/
			fi

			echo "[$NAME $VERSION] (Update) Updating server $SERVER_INSTANCE..."

			if [ -f $SRV_DIR/$SERVER_INSTANCE/server.jar.old ] ; then
				rm $SRV_DIR/$SERVER_INSTANCE/server.jar.old
			fi
			mv $SRV_DIR/$SERVER_INSTANCE/server.jar $SRV_DIR/$SERVER_INSTANCE/server.jar.old

			while [[ "$JAR_SHA1" != "$(sha1sum $SRV_DIR/$SERVER_INSTANCE/server.jar | awk '{print $1}')" ]]; do
				if [ -f $SRV_DIR/$SERVER_INSTANCE/server.jar ] ; then
					rm $SRV_DIR/$SERVER_INSTANCE/server.jar
				fi
				wget -O $SRV_DIR/$SERVER_INSTANCE/server.jar "$JAR_URL"
			done

			if [ -f $SRV_DIR/$SERVER_INSTANCE/server.jar ] ; then
				echo "[$NAME $VERSION] (Update) Update for server $SERVER_INSTANCE completed."
				echo "$LATEST_VERSION" > $UPDATE_DIR/$SERVER_INSTANCE/installed.version
				echo "$JAR_SHA1" > $UPDATE_DIR/$SERVER_INSTANCE/installed.sha1
			else
				echo "[$NAME $VERSION] (Update) Update for server $SERVER_INSTANCE failed. Restoring old server.jar file."
				mv $SRV_DIR/$SERVER_INSTANCE/server.jar.old $SRV_DIR/$SERVER_INSTANCE/server.jar
				UPDATE_FAILED="1"
			fi

			if [ "$WAS_ACTIVE" == "1" ]; then
				if [[ "$(echo $SERVER_SERVICE | awk -F '@' '{print $1}')" == "$SERVICE_NAME-tmpfs" ]]; then
					mkdir -p "$TMPFS_DIR/$SERVER_INSTANCE"
				fi

				sleep 1
				if [[ "$UPDATE_IGNORE_FAILED_ACTIVATIONS" == "1" ]]; then
					script_start $SERVER_INSTANCE "ignore"
				else
					script_start $SERVER_INSTANCE
				fi
			fi

			if [[ "$UPDATE_FAILED" == "1" ]]; then
				if [[ "$DISCORD_UPDATE" == "1" ]]; then
					script_discord_message "$DISCORD_COLOR_UPDATE" "Server update for server $SERVER_INSTANCE failed."
				fi
				if [[ "$EMAIL_UPDATE" == "1" ]]; then
					script_email_message "$NAME" "Notification: Update failed for server $SERVER_INSTANCE" "The script failed to update server $SERVER_INSTANCE."
				fi
			else
				if [[ "$DISCORD_UPDATE" == "1" ]]; then
					script_discord_message "$DISCORD_COLOR_UPDATE" "Server update complete."
				fi
				if [[ "$EMAIL_UPDATE" == "1" ]]; then
					script_email_message "$NAME" "Notification: Update" "Server was updated. Please check the update notes if there are any additional steps to take."
				fi
			fi
		elif [[ "$JAR_SHA1" == "$INSTALLED_SHA1" ]]; then
			echo "[$NAME $VERSION] (Update) No new updates for server $SERVER_INSTANCE detected."
			echo "[$NAME $VERSION] (Update) Server $SERVER_INSTANCE installed version: $INSTALLED_VERSION, SHA1: $INSTALLED_SHA1"
		fi
	done
}

#--------------------------

#Enable automatic world saving
script_saveon() {
	for SERVER_SERVICE in $(systemctl --user list-units -all --no-legend --no-pager --plain $SERVICE_NAME@*.service $SERVICE_NAME-tmpfs@*.service | awk '{print $1}'); do
		export SERVER_INSTANCE=$(echo $SERVER_SERVICE | awk -F '@' '{print $2}' | awk -F '.service' '{print $1}')
		if [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "active" ]] && [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "enabled" ]]; then
			echo "[$NAME $VERSION] (Save on) Enabling autosaving for server $SERVER_INSTANCE has been initiated."
			( sleep 5 && tmux -L $SERVICE_NAME-$SERVER_INSTANCE-tmux.sock send-keys -t $NAME.0 'save-on' ENTER ) &
			timeout $TIMEOUT_SAVE /bin/bash -c '
			while read line; do
				if [[ "$line" =~ "[Server thread/INFO]" ]] && [[ "$line" =~ "Automatic saving is now enabled" ]]; then
					echo "[$NAME $VERSION] (Save on) Enabling autosaving for server $SERVER_INSTANCE complete."
					/usr/bin/tmux -L $SERVICE_NAME-$SERVER_INSTANCE-tmux.sock send-keys -t $NAME.0 "say Automatic world saving is enabled." ENTER
					break
				elif [[ "$line" =~ "[Server thread/INFO]" ]] && [[ "$line" =~ " Turned on world auto-saving" ]]; then
					echo "[$NAME $VERSION] (Save on) Enabling autosaving for server $SERVER_INSTANCE complete."
					/usr/bin/tmux -L $SERVICE_NAME-$SERVER_INSTANCE-tmux.sock send-keys -t $NAME.0 "say Automatic world saving is enabled." ENTER
					break
				else
					echo "[$NAME $VERSION] (Save on) Enabling autosaving for server $SERVER_INSTANCE. Please wait..."
				fi
			done < <(tail -n1 -f /tmp/$SERVICE_NAME-$SERVER_INSTANCE-tmux.log)'
			EXIT_CODE="$?"
			if [[ "$EXIT_CODE" == "124" ]]; then
				echo "[$NAME $VERSION] (Save on) Enabling autosaving for server $SERVER_INSTANCE time limit exceeded."
			fi
		fi
	done
}

#--------------------------

#Disable automatic world saving
script_saveoff() {
	for SERVER_SERVICE in $(systemctl --user list-units -all --no-legend --no-pager --plain $SERVICE_NAME@*.service $SERVICE_NAME-tmpfs@*.service | awk '{print $1}'); do
		export SERVER_INSTANCE=$(echo $SERVER_SERVICE | awk -F '@' '{print $2}' | awk -F '.service' '{print $1}')
		if [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "active" ]] && [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "enabled" ]]; then
			echo "[$NAME $VERSION] (Save off) Disabling autosaving for server $SERVER_INSTANCE has been initiated."
			( sleep 5 && tmux -L $SERVICE_NAME-$SERVER_INSTANCE-tmux.sock send-keys -t $NAME.0 'save-off' ENTER ) &
			timeout $TIMEOUT_SAVE /bin/bash -c '
			while read line; do
				if [[ "$line" =~ "[Server thread/INFO]" ]] && [[ "$line" =~ "Automatic saving is now disabled" ]]; then
					echo "[$NAME $VERSION] (Save off) Disabling autosaving for server $SERVER_INSTANCE complete."
					/usr/bin/tmux -L $SERVICE_NAME-$SERVER_INSTANCE-tmux.sock send-keys -t $NAME.0 "say Automatic world saving is disabled." ENTER
					break
				elif [[ "$line" =~ "[Server thread/INFO]" ]] && [[ "$line" =~ "Turned off world auto-saving" ]]; then
					echo "[$NAME $VERSION] (Save off) Disabling autosaving for server $SERVER_INSTANCE complete."
					/usr/bin/tmux -L $SERVICE_NAME-$SERVER_INSTANCE-tmux.sock send-keys -t $NAME.0 "say Automatic world saving is disabled." ENTER
					break
				else
					echo "[$NAME $VERSION] (Save off) Deactivating autosaving for server $SERVER_INSTANCE. Please wait..."
				fi
			done < <(tail -n1 -f /tmp/$SERVICE_NAME-$SERVER_INSTANCE-tmux.log)'
			EXIT_CODE="$?"
			if [[ "$EXIT_CODE" == "124" ]]; then
				echo "[$NAME $VERSION] (Save on) Disabling autosaving for server $SERVER_INSTANCE time limit exceeded."
			fi
		fi
	done
}

#--------------------------

#Issue the save command to the server
script_save() {
	for SERVER_SERVICE in $(systemctl --user list-units -all --no-legend --no-pager --plain $SERVICE_NAME@*.service $SERVICE_NAME-tmpfs@*.service | awk '{print $1}'); do
		export SERVER_INSTANCE=$(echo $SERVER_SERVICE | awk -F '@' '{print $2}' | awk -F '.service' '{print $1}')
		if [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "active" ]] && [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "enabled" ]]; then
			echo "[$NAME $VERSION] (Save) Save game to disk for server $SERVER_INSTANCE has been initiated."
			( sleep 5 && tmux -L $SERVICE_NAME-$SERVER_INSTANCE-tmux.sock send-keys -t $NAME.0 'save-all' ENTER ) &
			timeout $TIMEOUT_SAVE /bin/bash -c '
			while read line; do
				if [[ "$line" =~ "[Server thread/INFO]" ]] && [[ "$line" =~ "Saved the game" ]]; then
					echo "[$NAME $VERSION] (Save) Save game to disk for server $SERVER_INSTANCE complete."
					/usr/bin/tmux -L $SERVICE_NAME-$SERVER_INSTANCE-tmux.sock send-keys -t $NAME.0 "say World save complete." ENTER
					break
				elif [[ "$line" =~ "[Server thread/INFO]" ]] && [[ "$line" =~ "Saved the world" ]]; then
					echo "[$NAME $VERSION] (Save) Save game to disk for server $SERVER_INSTANCE complete."
					/usr/bin/tmux -L $SERVICE_NAME-$SERVER_INSTANCE-tmux.sock send-keys -t $NAME.0 "say World save complete." ENTER
					break
				else
					echo "[$NAME $VERSION] (Save) Save game to disk for server $SERVER_INSTANCE is in progress. Please wait..."
				fi
			done < <(tail -n1 -f /tmp/$SERVICE_NAME-$SERVER_INSTANCE-tmux.log)'
			EXIT_CODE="$?"
			if [[ "$EXIT_CODE" == "124" ]]; then
				echo "[$NAME $VERSION] (Save on) Save game to disk for server $SERVER_INSTANCE time limit exceeded."
			fi
		fi
	done
}

#--------------------------

#Clear all drops in the world
script_cleardrops() {
	for SERVER_SERVICE in $(systemctl --user list-units -all --no-legend --no-pager --plain $SERVICE_NAME@*.service $SERVICE_NAME-tmpfs@*.service | awk '{print $1}'); do
		export SERVER_INSTANCE=$(echo $SERVER_SERVICE | awk -F '@' '{print $2}' | awk -F '.service' '{print $1}')
		if [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "active" ]] && [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "enabled" ]]; then
			echo "[$NAME $VERSION] (Clear drops) Clearing drops in 1 minute for server $SERVER_INSTANCE."
			( sleep 5 &&
			/usr/bin/tmux -L $SERVICE_NAME-$SERVER_INSTANCE-tmux.sock send-keys -t $NAME.0 "say Warning! Clearing all drops in 1 minutes!" ENTER &&
			sleep 30 &&
			/usr/bin/tmux -L $SERVICE_NAME-$SERVER_INSTANCE-tmux.sock send-keys -t $NAME.0 "say Warning! Clearing all drops in 30 seconds!" ENTER &&
			sleep 15 &&
			/usr/bin/tmux -L $SERVICE_NAME-$SERVER_INSTANCE-tmux.sock send-keys -t $NAME.0 "say Warning! Clearing all drops in 15 seconds!" ENTER &&
			sleep 5 &&
			/usr/bin/tmux -L $SERVICE_NAME-$SERVER_INSTANCE-tmux.sock send-keys -t $NAME.0 "say Warning! Clearing all drops in 10 seconds!" ENTER &&
			sleep 5 &&
			/usr/bin/tmux -L $SERVICE_NAME-$SERVER_INSTANCE-tmux.sock send-keys -t $NAME.0 "say Warning! Clearing all drops in 5 seconds!" ENTER &&
			sleep 1 &&
			/usr/bin/tmux -L $SERVICE_NAME-$SERVER_INSTANCE-tmux.sock send-keys -t $NAME.0 "say Warning! Clearing all drops in 4 seconds!" ENTER &&
			sleep 1 &&
			/usr/bin/tmux -L $SERVICE_NAME-$SERVER_INSTANCE-tmux.sock send-keys -t $NAME.0 "say Warning! Clearing all drops in 3 seconds!" ENTER &&
			sleep 1 &&
			/usr/bin/tmux -L $SERVICE_NAME-$SERVER_INSTANCE-tmux.sock send-keys -t $NAME.0 "say Warning! Clearing all drops in 2 seconds!" ENTER &&
			sleep 1 &&
			/usr/bin/tmux -L $SERVICE_NAME-$SERVER_INSTANCE-tmux.sock send-keys -t $NAME.0 "say Warning! Clearing all drops in 1 seconds!" ENTER &&
			sleep 1 &&
			/usr/bin/tmux -L $SERVICE_NAME-$SERVER_INSTANCE-tmux.sock send-keys -t $NAME.0 "say Clearing drops." ENTER &&
			/usr/bin/tmux -L $SERVICE_NAME-$SERVER_INSTANCE-tmux.sock send-keys -t $NAME.0 "/kill @e[type=item]" ENTER &&
			sleep 1 ) &
			timeout $TIMEOUT_SAVE /bin/bash -c '
			while read line; do
				if [[ "$line" =~ "/kill @e[type=item]" ]]; then
					echo "[$NAME $VERSION] (Clear Drops) Clearing drops for server $SERVER_INSTANCE complete."
					/usr/bin/tmux -L $SERVICE_NAME-$SERVER_INSTANCE-tmux.sock send-keys -t $NAME.0 "say Clearing drops complete." ENTER
					break
				else
					echo "[$NAME $VERSION] (Clear drops) Clearing drops for server $SERVER_INSTANCE in progress. Please wait..."
				fi
			done < <(tail -n1 -f /tmp/$SERVICE_NAME-$SERVER_INSTANCE-tmux.log)'
			EXIT_CODE="$?"
			if [[ "$EXIT_CODE" == "124" ]]; then
				echo "[$NAME $VERSION] (Save) Save time limit for server $SERVER_INSTANCE exceeded."
			fi
		fi
	done
}

#--------------------------

#First timer function for systemd timers to execute parts of the script in order without interfering with each other
script_timer_one() {
	RUNNING_SERVERS="0"
	for SERVER_SERVICE in $(systemctl --user list-units -all --no-legend --no-pager --plain $SERVICE_NAME@*.service $SERVICE_NAME-tmpfs@*.service | awk '{print $1}'); do
		SERVER_INSTANCE=$(echo $SERVER_SERVICE | awk -F '@' '{print $2}' | awk -F '.service' '{print $1}')
		if [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "inactive" ]] && [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "enabled" ]]; then
			echo "[$NAME $VERSION] (Status) Server $SERVER_INSTANCE is not running."
		elif [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "failed" ]] && [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "enabled" ]]; then
			echo "[$NAME $VERSION] (Status) Server $SERVER_INSTANCE is in failed state. Please check logs."
		elif [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "activating" ]] && [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "enabled" ]]; then
			echo "[$NAME $VERSION] (Status) Server $SERVER_INSTANCE is activating. Aborting until next scheduled execution."
		elif [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "deactivating" ]] && [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "enabled" ]]; then
			echo "[$NAME $VERSION] (Status) Server $SERVER_INSTANCE is in deactivating. Aborting until next scheduled execution."
		elif [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "active" ]] && [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "enabled" ]]; then
			echo "[$NAME $VERSION] (Status) Server $SERVER_INSTANCE is running."
			RUNNING_SERVERS=$(($RUNNING_SERVERS + 1))
		fi
	done

	if [ $RUNNING_SERVERS -gt "0" ]; then
		script_remove_old_files
		script_tmpfs_space_check
		script_cleardrops
		script_saveoff
		script_save
		script_sync
		script_backup
		script_saveon
		if [[ "$GAME_SERVER_UPDATES" == "1" ]]; then
			script_update
		fi
	fi
}

#--------------------------

#Second timer function for systemd timers to execute parts of the script in order without interfering with each other
script_timer_two() {
	RUNNING_SERVERS="0"
	for SERVER_SERVICE in $(systemctl --user list-units -all --no-legend --no-pager --plain $SERVICE_NAME@*.service $SERVICE_NAME-tmpfs@*.service | awk '{print $1}'); do
		SERVER_INSTANCE=$(echo $SERVER_SERVICE | awk -F '@' '{print $2}' | awk -F '.service' '{print $1}')
		if [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "inactive" ]] && [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "enabled" ]]; then
			echo "[$NAME $VERSION] (Status) Server $SERVER_INSTANCE is not running."
		elif [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "failed" ]] && [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "enabled" ]]; then
			echo "[$NAME $VERSION] (Status) Server $SERVER_INSTANCE is in failed state. Please check logs."
		elif [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "activating" ]] && [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "enabled" ]]; then
			echo "[$NAME $VERSION] (Status) Server $SERVER_INSTANCE is activating. Aborting until next scheduled execution."
		elif [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "deactivating" ]] && [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "enabled" ]]; then
			echo "[$NAME $VERSION] (Status) Server $SERVER_INSTANCE is in deactivating. Aborting until next scheduled execution."
		elif [[ "$(systemctl --user show -p ActiveState --value $SERVER_SERVICE)" == "active" ]] && [[ "$(systemctl --user show -p UnitFileState --value $SERVER_SERVICE)" == "enabled" ]]; then
			echo "[$NAME $VERSION] (Status) Server $SERVER_INSTANCE is running."
			RUNNING_SERVERS=$(($RUNNING_SERVERS + 1))
		fi
	done

	if [ $RUNNING_SERVERS -gt "0" ]; then
		script_remove_old_files
		script_tmpfs_space_check
		script_saveoff
		script_save
		script_sync
		script_saveon
		if [[ "$GAME_SERVER_UPDATES" == "1" ]]; then
			script_update
		fi
	fi
}

#--------------------------

#Runs the diagnostics
script_diagnostics() {
	echo "Initializing diagnostics. Please wait..."
	echo ""
	sleep 3

	#Check package versions
	echo "Checkign package versions:"
	if [ -f "/usr/bin/pacman" ]; then
		echo "bash version:$(pacman -Qi bash | grep "^Version" | cut -d : -f2)"
		echo "coreutils version:$(pacman -Qi coreutils | grep "^Version" | cut -d : -f2)"
		echo "sudo version:$(pacman -Qi sudo | grep "^Version" | cut -d : -f2)"
		echo "grep version:$(pacman -Qi grep | grep "^Version" | cut -d : -f2)"
		echo "sed version:$(pacman -Qi sed | grep "^Version" | cut -d : -f2)"
		echo "awk version:$(pacman -Qi awk | grep "^Version" | cut -d : -f2)"
		echo "curl version:$(pacman -Qi curl | grep "^Version" | cut -d : -f2)"
		echo "rsync version:$(pacman -Qi rsync | grep "^Version" | cut -d : -f2)"
		echo "wget version:$(pacman -Qi wget | grep "^Version" | cut -d : -f2)"
		echo "findutils version:$(pacman -Qi findutils | grep "^Version" | cut -d : -f2)"
		echo "tmux version:$(pacman -Qi tmux | grep "^Version" | cut -d : -f2)"
		echo "jq version:$(pacman -Qi jq | grep "^Version" | cut -d : -f2)"
		echo "zip version:$(pacman -Qi zip | grep "^Version" | cut -d : -f2)"
		echo "unzip version:$(pacman -Qi unzip | grep "^Version" | cut -d : -f2)"
		echo "p7zip version:$(pacman -Qi p7zip | grep "^Version" | cut -d : -f2)"
		echo "postfix version:$(pacman -Qi postfix | grep "^Version" | cut -d : -f2)"
		echo "samba version:$(pacman -Qi samba | grep "^Version" | cut -d : -f2)"
	elif [ -f "/usr/bin/dpkg" ]; then
		echo "bash version:$(dpkg -s bash | grep "^Version" | cut -d : -f2)"
		echo "coreutils version:$(dpkg -s coreutils | grep "^Version" | cut -d : -f2)"
		echo "sudo version:$(dpkg -s sudo | grep "^Version" | cut -d : -f2)"
		echo "libpam-systemd version:$(dpkg -s libpam-systemd | grep "^Version" | cut -d : -f2)"
		echo "grep version:$(dpkg -s grep | grep "^Version" | cut -d : -f2)"
		echo "sed version:$(dpkg -s sed | grep "^Version" | cut -d : -f2)"
		echo "gawk version:$(dpkg -s gawk | grep "^Version" | cut -d : -f2)"
		echo "curl version:$(dpkg -s curl | grep "^Version" | cut -d : -f2)"
		echo "rsync version:$(dpkg -s rsync | grep "^Version" | cut -d : -f2)"
		echo "wget version:$(dpkg -s wget | grep "^Version" | cut -d : -f2)"
		echo "findutils version:$(dpkg -s findutils | grep "^Version" | cut -d : -f2)"
		echo "tmux version:$(dpkg -s tmux | grep "^Version" | cut -d : -f2)"
		echo "jq version:$(dpkg -s jq | grep "^Version" | cut -d : -f2)"
		echo "zip version:$(dpkg -s zip | grep "^Version" | cut -d : -f2)"
		echo "unzip version:$(dpkg -s unzip | grep "^Version" | cut -d : -f2)"
		echo "p7zip version:$(dpkg -s p7zip | grep "^Version" | cut -d : -f2)"
		echo "postfix version:$(dpkg -s postfix | grep "^Version" | cut -d : -f2)"
	fi
	echo ""

	echo "Checking if files and folders present:"
	#Check if files/folders present
	if [ -f "/usr/bin/$SERVICE_NAME-script" ] ; then
		echo "Script present: Yes"
	else
		echo "Script present: No"
	fi

	if [ -d "$CONFIG_DIR" ]; then
		echo "Configuration folder present: Yes"
	else
		echo "Configuration folder present: No"
	fi

	if [ -d "$BCKP_DIR" ]; then
		echo "Backups folder present: Yes"
	else
		echo "Backups folder present: No"
	fi

	if [ -d "$LOF_DIR" ]; then
		echo "Logs folder present: Yes"
	else
		echo "Logs folder present: No"
	fi

	if [ -d "$UPDATE_DIR" ]; then
		echo "Updates folder present: Yes"
	else
		echo "Updates folder present: No"
	fi

	if [ -f "$CONFIG_DIR/$SERVICE_NAME-script.conf" ] ; then
		echo "Script configuration file present: Yes"
	else
		echo "Script configuration file present: No"
	fi

	if [ -f "$CONFIG_DIR/$SERVICE_NAME-steam.conf" ] ; then
		echo "Steam configuration file present: Yes"
	else
		echo "Steam configuration file present: No"
	fi

	if [ -f "$CONFIG_DIR/$SERVICE_NAME-discord.conf" ] ; then
		echo "Discord configuration file present: Yes"
	else
		echo "Discord configuration file present: No"
	fi

	if [ -f "$CONFIG_DIR/$SERVICE_NAME-email.conf" ] ; then
		echo "Email configuration file present: Yes"
	else
		echo "Email configuration file present: No"
	fi

	if [ -f "/srv/$SERVICE_NAME/.config/systemd/user/$SERVICE_NAME-mkdir-tmpfs@.service" ]; then
		echo "Tmpfs mkdir service present: Yes"
	else
		echo "Tmpfs mkdir service present: No"
	fi

	if [ -f "/srv/$SERVICE_NAME/.config/systemd/user/$SERVICE_NAME-tmpfs@.service" ]; then
		echo "Tmpfs service for vanilla present: Yes"
	else
		echo "Tmpfs service for vanilla present: No"
	fi

	if [ -f "/srv/$SERVICE_NAME/.config/systemd/user/$SERVICE_NAME@.service" ]; then
		echo "Basic service for vanilla present: Yes"
	else
		echo "Basic service for vanilla present: No"
	fi

	if [ -f "/srv/$SERVICE_NAME/.config/systemd/user/$SERVICE_NAME-timer-1.timer" ]; then
		echo "Timer 1 timer present: Yes"
	else
		echo "Timer 1 timer present: No"
	fi

	if [ -f "/srv/$SERVICE_NAME/.config/systemd/user/$SERVICE_NAME-timer-1.service" ]; then
		echo "Timer 1 service present: Yes"
	else
		echo "Timer 1 service present: No"
	fi

	if [ -f "/srv/$SERVICE_NAME/.config/systemd/user/$SERVICE_NAME-timer-2.timer" ]; then
		echo "Timer 2 timer present: Yes"
	else
		echo "Timer 2 timer present: No"
	fi

	if [ -f "/srv/$SERVICE_NAME/.config/systemd/user/$SERVICE_NAME-timer-2.service" ]; then
		echo "Timer 2 service present: Yes"
	else
		echo "Timer 2 service present: No"
	fi

	if [ -f "/srv/$SERVICE_NAME/.config/systemd/user/$SERVICE_NAME-serversync@.service" ]; then
		echo "ServerSync service present: Yes"
	else
		echo "ServerSync service present: No"
	fi

	if [ -f "/srv/$SERVICE_NAME/.config/systemd/user/$SERVICE_NAME-send-notification@.service" ]; then
		echo "Notification sending service present: Yes"
	else
		echo "Notification sending service present: No"
	fi

	echo "Diagnostics complete."
}

#--------------------------

#Install tmux configuration for specific server when first ran
script_server_tmux_install() {
	if [ -z "$2" ]; then
		echo "[$NAME $VERSION] (Server tmux configuration) Installing tmux configuration for server $1."
		TMUX_CONFIG_FILE="/tmp/$SERVICE_NAME-$1-tmux.conf"
	elif [[ "$2" == "override" ]]; then
		echo "[$NAME $VERSION] (Server tmux configuration) Installing tmux override configuration for server $1."
		TMUX_CONFIG_FILE="$CONFIG_DIR/$SERVICE_NAME-$1-tmux.conf"
	fi

	if [ -f $CONFIG_DIR/$SERVICE_NAME-$1-tmux.conf ]; then
		cp $CONFIG_DIR/$SERVICE_NAME-$1-tmux.conf /tmp/$SERVICE_NAME-$1-tmux.conf
	else
		if [ ! -f $TMUX_CONFIG_FILE ]; then
			touch $TMUX_CONFIG_FILE
			cat > $TMUX_CONFIG_FILE <<- EOF
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
			bind-key r source-file /tmp/$SERVICE_NAME-$1-tmux.conf \; display-message "Config reloaded!"

			set-hook -g session-created 'resize-window -y 24 -x 10000'
			set-hook -g session-created "pipe-pane -o 'tee >> /tmp/$SERVICE_NAME-$1-tmux.log'"
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
			echo "[$NAME $VERSION] (Server tmux configuration) Tmux configuration for server $1 installed successfully."
		fi
	fi
}

#--------------------------

#Configures discord integration
script_config_discord() {
	echo ""
	read -p "Enable discord notifications (y/n): " INSTALL_DISCORD_ENABLE
	if [[ "$INSTALL_DISCORD_ENABLE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
		echo ""
		echo "You are able to add multiple webhooks for the script to use in the discord_webhooks.txt file located in the config folder."
		echo "EACH ONE HAS TO BE IN IT'S OWN LINE!"
		echo ""
		read -p "Enter your first webhook for the server: " INSTALL_DISCORD_WEBHOOK
		if [[ "$INSTALL_DISCORD_WEBHOOK" == "" ]]; then
			INSTALL_DISCORD_WEBHOOK="none"
		fi
		echo ""
		read -p "Discord notifications for game updates? (y/n): " INSTALL_DISCORD_UPDATE_ENABLE
			if [[ "$INSTALL_DISCORD_UPDATE_ENABLE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
				INSTALL_DISCORD_UPDATE="1"
			else
				INSTALL_DISCORD_UPDATE="0"
			fi
		echo ""
		read -p "Discord notifications for server startup? (y/n): " INSTALL_DISCORD_START_ENABLE
			if [[ "$INSTALL_DISCORD_START_ENABLE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
				INSTALL_DISCORD_START="1"
			else
				INSTALL_DISCORD_START="0"
			fi
		echo ""
		read -p "Discord notifications for server shutdown? (y/n): " INSTALL_DISCORD_STOP_ENABLE
			if [[ "$INSTALL_DISCORD_STOP_ENABLE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
				INSTALL_DISCORD_STOP="1"
			else
				INSTALL_DISCORD_STOP="0"
			fi
		echo ""
		read -p "Discord notifications for crashes? (y/n): " INSTALL_DISCORD_CRASH_ENABLE
			if [[ "$INSTALL_DISCORD_CRASH_ENABLE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
				INSTALL_DISCORD_CRASH="1"
			else
				INSTALL_DISCORD_CRASH="0"
			fi
		echo ""
		read -p "Discord notifications for tmpfs partition being close to full? (y/n): " INSTALL_DISCORD_TMPFS_SPACE_ENABLE
			if [[ "$INSTALL_DISCORD_TMPFS_SPACE_ENABLE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
				INSTALL_DISCORD_TMPFS_SPACE="1"
			else
				INSTALL_DISCORD_TMPFS_SPACE="0"
			fi
	elif [[ "$INSTALL_DISCORD_ENABLE" =~ ^([nN][oO]|[nN])$ ]]; then
		INSTALL_DISCORD_UPDATE="0"
		INSTALL_DISCORD_START="0"
		INSTALL_DISCORD_STOP="0"
		INSTALL_DISCORD_CRASH="0"
		INSTALL_DISCORD_TMPFS_SPACE="0"
	fi

	echo "Writing configuration file..."
	touch $CONFIG_DIR/$SERVICE_NAME-discord.conf
	echo 'discord_update='"$INSTALL_DISCORD_UPDATE" > $CONFIG_DIR/$SERVICE_NAME-discord.conf
	echo 'discord_start='"$INSTALL_DISCORD_START" >> $CONFIG_DIR/$SERVICE_NAME-discord.conf
	echo 'discord_stop='"$INSTALL_DISCORD_STOP" >> $CONFIG_DIR/$SERVICE_NAME-discord.conf
	echo 'discord_crash='"$INSTALL_DISCORD_CRASH" >> $CONFIG_DIR/$SERVICE_NAME-discord.conf
	echo 'discord_tmpfs_space='"$INSTALL_DISCORD_TMPFS_SPACE" >> $CONFIG_DIR/$SERVICE_NAME-discord.conf
	echo 'discord_color_prestart=16776960' >> $CONFIG_DIR/$SERVICE_NAME-discord.conf
	echo 'discord_color_poststart=65280' >> $CONFIG_DIR/$SERVICE_NAME-discord.conf
	echo 'discord_color_prestop=16776960' >> $CONFIG_DIR/$SERVICE_NAME-discord.conf
	echo 'discord_color_poststop=65280' >> $CONFIG_DIR/$SERVICE_NAME-discord.conf
	echo 'discord_color_update=47083' >> $CONFIG_DIR/$SERVICE_NAME-discord.conf
	echo 'discord_color_crash=16711680' >> $CONFIG_DIR/$SERVICE_NAME-discord.conf
	echo 'discord_color_tmpfs_space=16711680' >> $CONFIG_DIR/$SERVICE_NAME-discord.conf
	echo "$INSTALL_DISCORD_WEBHOOK" > $CONFIG_DIR/discord_webhooks.txt
	echo "Done"
}

#--------------------------

#Configures email integration
script_config_email() {
	echo ""
	read -p "Enable email notifications (y/n): " INSTALL_EMAIL_ENABLE
	if [[ "$INSTALL_EMAIL_ENABLE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
		echo ""
		read -p "Enter the email that will send the notifications (example: sender@gmail.com): " INSTALL_EMAIL_SENDER
		echo ""
		read -p "Enter the email that will recieve the notifications (example: recipient@gmail.com): " INSTALL_EMAIL_RECIPIENT
		echo ""
		read -p "Email notifications for game updates? (y/n): " INSTALL_EMAIL_UPDATE_ENABLE
			if [[ "$INSTALL_EMAIL_UPDATE_ENABLE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
				INSTALL_EMAIL_UPDATE="1"
			else
				INSTALL_EMAIL_UPDATE="0"
			fi
		echo ""
		read -p "Email notifications for server startup? (WARNING: this can be anoying) (y/n): " INSTALL_EMAIL_START_ENABLE
			if [[ "$INSTALL_EMAIL_START_ENABLE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
				INSTALL_EMAIL_START="1"
			else
				INSTALL_EMAIL_START="0"
			fi
		echo ""
		read -p "Email notifications for server shutdown? (WARNING: this can be anoying) (y/n): " INSTALL_EMAIL_STOP_ENABLE
			if [[ "$INSTALL_EMAIL_STOP_ENABLE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
				INSTALL_EMAIL_STOP="1"
			else
				INSTALL_EMAIL_STOP="0"
			fi
		echo ""
		read -p "Email notifications for crashes? (y/n): " INSTALL_EMAIL_CRASH_ENABLE
			if [[ "$INSTALL_EMAIL_CRASH_ENABLE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
				INSTALL_EMAIL_CRASH="1"
			else
				INSTALL_EMAIL_CRASH="0"
			fi
		echo ""
		read -p "Email notifications for tmpfs partition being close to full? (y/n): " INSTALL_EMAIL_TMPFS_SPACE_ENABLE
			if [[ "$INSTALL_EMAIL_TMPFS_SPACE_ENABLE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
				INSTALL_EMAIL_TMPFS_SPACE="1"
			else
				INSTALL_EMAIL_TMPFS_SPACE="0"
			fi
		if [[ "$EUID" == "$(id -u root)" ]]; then
			read -p "Configure postfix? (y/n): " INSTALL_EMAIL_CONFIGURE
			if [[ "$INSTALL_EMAIL_CONFIGURE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
				echo ""
				read -p "Enter the relay host (example: smtp.gmail.com): " INSTALL_EMAIL_RELAY_HOST
				echo ""
				read -p "Enter the relay host port (example: 587): " INSTALL_EMAIL_RELAY_PORT
				echo ""
				read -p "Enter your password for $INSTALL_EMAIL_SENDER : " INSTALL_EMAIL_SENDER_PSW

				cat >> /etc/postfix/main.cf <<- EOF
				relayhost = [$INSTALL_EMAIL_RELAY_HOST]:$INSTALL_EMAIL_RELAY_PORT
				smtp_sasl_auth_enable = yes
				smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
				smtp_sasl_security_options = noanonymous
				smtp_tls_CApath = /etc/ssl/certs
				smtpd_tls_CApath = /etc/ssl/certs
				smtp_use_tls = yes
				EOF

				cat > /etc/postfix/sasl_passwd <<- EOF
				[$INSTALL_EMAIL_RELAY_HOST]:$INSTALL_EMAIL_RELAY_PORT    $INSTALL_EMAIL_SENDER:$INSTALL_EMAIL_SENDER_PSW
				EOF

				sudo chmod 400 /etc/postfix/sasl_passwd
				sudo postmap /etc/postfix/sasl_passwd
				sudo systemctl enable --now postfix
			fi
		else
			echo "Add the following lines to /etc/postfix/main.cf"
			echo "relayhost = [$INSTALL_EMAIL_RELAY_HOST]:$INSTALL_EMAIL_RELAY_HOST_PORT"
			echo "smtp_sasl_auth_enable = yes"
			echo "smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd"
			echo "smtp_sasl_security_options = noanonymous"
			echo "smtp_tls_CApath = /etc/ssl/certs"
			echo "smtpd_tls_CApath = /etc/ssl/certs"
			echo "smtp_use_tls = yes"
			echo ""
			echo "Add the following line to /etc/postfix/sasl_passwd"
			echo "[$INSTALL_EMAIL_RELAY_HOST]:$INSTALL_EMAIL_RELAY_HOST_PORT    $INSTALL_EMAIL_SENDER:$INSTALL_EMAIL_SENDER_PSW"
			echo ""
			echo "Execute the following commands:"
			echo "sudo chmod 400 /etc/postfix/sasl_passwd"
			echo "sudo postmap /etc/postfix/sasl_passwd"
			echo "sudo systemctl enable postfix"
		fi
	elif [[ "$INSTALL_EMAIL_ENABLE" =~ ^([nN][oO]|[nN])$ ]]; then
		INSTALL_EMAIL_SENDER="none"
		INSTALL_EMAIL_RECIPIENT="none"
		INSTALL_EMAIL_UPDATE="0"
		INSTALL_EMAIL_START="0"
		INSTALL_EMAIL_STOP="0"
		INSTALL_EMAIL_CRASH="0"
		INSTALL_EMAIL_TMPFS_SPACE="0"
	fi

	echo "Writing configuration file..."
	echo 'email_sender='"$INSTALL_EMAIL_SENDER" > $CONFIG_DIR/$SERVICE_NAME-email.conf
	echo 'email_recipient='"$INSTALL_EMAIL_RECIPIENT" >> $CONFIG_DIR/$SERVICE_NAME-email.conf
	echo 'email_update='"$INSTALL_EMAIL_UPDATE" >> $CONFIG_DIR/$SERVICE_NAME-email.conf
	echo 'email_start='"$INSTALL_EMAIL_START" >> $CONFIG_DIR/$SERVICE_NAME-email.conf
	echo 'email_stop='"$INSTALL_EMAIL_STOP" >> $CONFIG_DIR/$SERVICE_NAME-email.conf
	echo 'email_crash='"$INSTALL_EMAIL_CRASH" >> $CONFIG_DIR/$SERVICE_NAME-email.conf
	echo 'email_tmpfs_space='"$INSTALL_EMAIL_TMPFS_SPACE" >> $CONFIG_DIR/$SERVICE_NAME-email.conf
	chown $SERVICE_NAME:$SERVICE_NAME $CONFIG_DIR/$SERVICE_NAME-email.conf
	echo "Done"
}

#--------------------------

#Configures tmpfs integration
script_config_tmpfs() {
	echo ""
	read -p "Install tmpfs? (y/n): " INSTALL_TMPFS
	echo ""
	if [[ "$INSTALL_TMPFS" =~ ^([yY][eE][sS]|[yY])$ ]]; then
		read -p "Ramdisk size (I recommend at least 8GB): " INSTALL_TMPFS_SIZE
		echo "Installing ramdisk configuration"
		if [[ "$EUID" == "$(id -u root)" ]] ; then
			cat >> /etc/fstab <<- EOF

			# /mnt/tmpfs
			tmpfs				   $TMPFS_DIR		tmpfs		   rw,size=$INSTALL_TMPFS_SIZE,uid=$(id -u $SERVICE_NAME),mode=0777	0 0
			EOF
		else
			echo "Add the following line to /etc/fstab:"
			echo "tmpfs				   $TMPFS_DIR		tmpfs		   rw,size=$INSTALL_TMPFS_SIZE,uid=$(id -u $SERVICE_NAME),mode=0777	0 0"
		fi
	fi
}

#--------------------------

#Configures the script
script_config_script() {
	echo -e "${CYAN}Script configuration${NC}"
	echo -e ""
	echo -e "The script uses jq to download the vanilla server.jar from Mojang servers, however you have the option to manualy copy the files yourself."
	echo -e ""
	echo -e "The script can work either way. The $SERVICE_NAME user's home directory is located in /srv/$SERVICE_NAME and all files are located there."
	echo -e "This configuration installation will only install the essential configuration. No discord, email or tmpfs/ramdisk"
	echo -e "Default configuration will be applied and it can work without it. You can run the optional configuration for each using the"
	echo -e "following arguments with the script:"
	echo -e ""
	echo -e "${GREEN}config_discord ${RED}- ${GREEN}Configures discord integration.${NC}"
	echo -e "${GREEN}config_email   ${RED}- ${GREEN}Configures email integration. Due to postfix configuration files being in /etc this has to be executed as root.${NC}"
	echo -e "${GREEN}config_tmpfs   ${RED}- ${GREEN}Configures tmpfs/ramdisk. Due to it adding a line to /etc/fstab this has to be executed as root.${NC}"
	echo -e ""
	echo -e ""
	read -p "Press any key to continue" -n 1 -s -r
	echo ""

	echo "Enabling services"
	systemctl --user enable --now $SERVICE_NAME-timer-1.timer
	systemctl --user enable --now $SERVICE_NAME-timer-2.timer

	echo "Adding first server"
	script_add_server

	read -p "Install ServerSync (Usefull for syncing custom modpacks with players)? (y/n): " SERVERSYNC_SETUP
	if [[ "$SERVERSYNC_SETUP" =~ ^([yY][eE][sS]|[yY])$ ]]; then
		echo "Downloading and installing ServerSync from github."
		mkdir -p "/srv/$SERVICE_NAME/server01_sync"
		curl -s https://api.github.com/repos/superzanti/ServerSync/releases/latest | jq -r ".assets[] | select(.name | contains(\"jar\")) | .browser_download_url" | wget -i -
		mv *serversync* /srv/$SERVICE_NAME/server01_sync
		systemctl --user enable $SERVICE_NAME-serversync@server01.service
	fi

	echo "Writing config files"

	touch $CONFIG_DIR/$SERVICE_NAME-script.conf
	echo 'script_bckp_delold=7' > $CONFIG_DIR/$SERVICE_NAME-script.conf
	echo 'script_log_delold=7' >> $CONFIG_DIR/$SERVICE_NAME-script.conf
	echo 'script_log_game_delold=7' >> $CONFIG_DIR/$SERVICE_NAME-script.conf
	echo 'script_update_game='"$INSTAL_GAME_SERVER_UPDATES" >> $CONFIG_DIR/$SERVICE_NAME-script.conf
	echo 'script_update_ignore_failed_startups=0' >> $CONFIG_DIR/$SERVICE_NAME-script.conf
	echo 'script_timeout_save=120' >> $CONFIG_DIR/$SERVICE_NAME-script.conf
	echo 'script_tmpfs_space=90' >> $CONFIG_DIR/$SERVICE_NAME-script.conf

	echo "Configuration complete"
	echo "For any settings you'll want to change, edit the files located in $CONFIG_DIR/"
	echo "To enable additional fuctions like discord, email and tmpfs execute the script with the help argument."
}

#--------------------------

#Do not allow for another instance of this script to run to prevent data loss
if [[ "pre-start" != "$1" ]] && [[ "post-start" != "$1" ]] && [[ "pre-stop" != "$1" ]] && [[ "post-stop" != "$1" ]] && [[ "send_notification_crash" != "$1" ]] && [[ "server_tmux_install" != "$1" ]] && [[ "attach" != "$1" ]] && [[ "status" != "$1" ]]; then
	SCRIPT_PID_CHECK=$(basename -- "$0")
	if pidof -x "$SCRIPT_PID_CHECK" -o $$ > /dev/null; then
		echo "An another instance of this script is already running, please clear all the sessions of this script before starting a new session"
		exit 2
	fi
fi

#--------------------------

#Check what user is executing the script and allow root to execute certain functions.
if [[ "$EUID" != "$(id -u $SERVICE_NAME)" ]] && [[ "config_email" != "$1" ]] && [[ "config_tmpfs" != "$1" ]]; then
	echo "This script is only able to be executed by the $SERVICE_NAME user."
	echo "The following functions can also be executed as root: config_email, config_tmpfs"
	exit 3
fi

#--------------------------

#Script help page
case "$1" in
	help)
		echo -e "${CYAN}Time: $(date +"%Y-%m-%d %H:%M:%S") ${NC}"
		echo -e "${CYAN}$NAME server script by 7thCore${NC}"
		echo "Version: $VERSION"
		echo ""
		echo "Basic script commands:"
		echo -e "${GREEN}diag   ${RED}- ${GREEN}Prints out package versions and if script files are installed.${NC}"
		echo -e "${GREEN}status ${RED}- ${GREEN}Display status of server.${NC}"
		echo ""
		echo "Configuration and installation:"
		echo -e "${GREEN}config_script  ${RED}- ${GREEN}Configures the script, enables the systemd services and installs the wine prefix.${NC}"
		echo -e "${GREEN}config_discord ${RED}- ${GREEN}Configures discord integration.${NC}"
		echo -e "${GREEN}config_email   ${RED}- ${GREEN}Configures email integration. Due to postfix configuration files being in /etc this has to be executed as root.${NC}"
		echo -e "${GREEN}config_tmpfs   ${RED}- ${GREEN}Configures tmpfs/ramdisk. Due to it adding a line to /etc/fstab this has to be executed as root.${NC}"
		echo ""
		echo "Server services managment:"
		echo -e "${GREEN}add_server                   ${RED}- ${GREEN}Adds a server instance.${NC}"
		echo -e "${GREEN}remove_server                ${RED}- ${GREEN}Removes a server instance.${NC}"
		echo -e "${GREEN}enable_services              ${RED}- ${GREEN}Enables all services dependant on the configuration file of the script.${NC}"
		echo -e "${GREEN}disable_services             ${RED}- ${GREEN}Disables all services. The server and the script will not start up on boot anymore.${NC}"
		echo -e "${GREEN}reload_services              ${RED}- ${GREEN}Reloads all services, dependant on the configuration file.${NC}"
		echo ""
		echo "Server and console managment:"
		echo -e "${GREEN}start <server number>        ${RED}- ${GREEN}Start the server. If the server number is not specified the function will start all servers.${NC}"
		echo -e "${GREEN}stop <server number>         ${RED}- ${GREEN}Stop the server. If the server number is not specified the function will stop all servers.${NC}"
		echo -e "${GREEN}restart <server number>      ${RED}- ${GREEN}Restart the server. If the server number is not specified the function will restart all servers.${NC}"
		echo -e "${GREEN}save                         ${RED}- ${GREEN}Issue the save command to all active servers.${NC}"
		echo -e "${GREEN}sync                         ${RED}- ${GREEN}Sync from tmpfs to hdd/ssd for all active server running on tmpfs.${NC}"
		echo -e "${GREEN}attach <server number>       ${RED}- ${GREEN}Attaches to the tmux session of the specified server.${NC}"
		echo ""
		echo "Backup managment:"
		echo -e "${GREEN}backup                       ${RED}- ${GREEN}Backup files if server running.${NC}"
		echo ""
		echo "Game specific functions:"
		echo -e "${GREEN}update                       ${RED}- ${GREEN}Update the server, if the server is running it will save it, shut it down, update it and restart it.${NC}"
		echo ""
		;;
#--------------------------
#Basic script functions
	diag)
		script_diagnostics
		;;
	status)
		script_status
		;;
#--------------------------
#Configuration and installation
	config_script)
		script_config_script
		;;
	config_discord)
		script_config_discord
		;;
	config_email)
		script_config_email
		;;
	config_tmpfs)
		script_config_tmpfs
		;;
#--------------------------
#Server services managment
	add_server)
		script_add_server
		;;
	remove_server)
		script_remove_server
		;;
	enable_services)
		script_enable_services_manual
		;;
	disable_services)
		script_disable_services_manual
		;;
	reload_services)
		script_reload_services
		;;
#--------------------------
#Server and console managment
	start)
		script_start $2
		;;
	stop)
		script_stop $2
		;;
	restart)
		script_restart $2
		;;
	save)
		script_save
		;;
	sync)
		script_sync
		;;
	attach)
		script_attach $2
		;;
#--------------------------
#Backup managment
	backup)
		script_backup
		;;
#--------------------------
#Game specific functions
	update)
		script_update
		;;
#--------------------------
#Hidden functions meant for systemd service use
	pre-start)
		script_prestart $2 $3
		;;
	post-start)
		script_poststart $2
		;;
	pre-stop)
		script_prestop $2
		;;
	post-stop)
		script_poststop $2 $3
		;;
	send_notification_crash)
		script_send_notification_crash $2
		;;
	server_tmux_install)
		script_server_tmux_install $2 $3
		;;
	timer_one)
		script_timer_one
		;;
	timer_two)
		script_timer_two
		;;
	*)
#--------------------------
#General output if the script does not recognise the argument provided
	echo -e "${CYAN}Time: $(date +"%Y-%m-%d %H:%M:%S") ${NC}"
	echo -e "${CYAN}$NAME server script by 7thCore${NC}"
	echo ""
	echo "For more detailed information, execute the script with the -help argument"
	echo ""
	echo -e "${GREEN}Basic script commands${RED}: ${GREEN}help, diag, status${NC}"
	echo -e "${GREEN}Configuration and installation${RED}: ${GREEN}config_script, config_discord, config_email, config_tmpfs${NC}"
	echo -e "${GREEN}Server services managment${RED}: ${GREEN}add_server, remove_server, enable_services, disable_services, reload_services${NC}"
	echo -e "${GREEN}Server and console managment${RED}: ${GREEN}start, start_no_err, stop,restart, save, sync, attach${NC}"
	echo -e "${GREEN}Backup managment${RED}: ${GREEN}backup${NC}"
	echo -e "${GREEN}Game specific functions${RED}: ${GREEN}update, delete_save${NC}"
	exit 1
	;;
esac

exit 0
