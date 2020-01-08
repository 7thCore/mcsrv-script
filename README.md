# mcsrv-script
Bash script for running Minecraft on a linux server

**Required packages**

-java

-rsync

-tmux

-postfix (optional for email notifications)

-zip (optional but required if using the email feature)

**Features:**

-auto backups

-auto updates

-script logging

-auto restart if crashed

-delete old backups

-delete old logs

-run from ramdisk

-sync from ramdisk to hdd/ssd

-start on os boot

-shutdown gracefully on os shutdown

-script auto update from github

-send email notifications after 3 crashes within a 5 minute time limit (optional)

-send email notifications on server startup (optional)

-send email notifications when server shutdown (optional)

-send discord notifications after 3 crashes within a 5 minute time limit (optional)

-send discord notifications on server startup (optional)

-send discord notifications when server shutdown (optional)

-supports multiple discord webhooks

**Instructions:**

Log in to your server with ssh and execute:

```git clone https://github.com/7thCore/mcsrv-script```

Make it executable:

```chmod +x ./mcsrv-script.bash```

If you plan on using a ramdisk to run your server from, the script will give you that option.

Now for the installation.

If you wish you can have the script install the required packages with (Only for Arch Linux & Ubuntu 19.10):

```sudo ./mcsrv-script.bash -install_packages```

After that run the script with root permitions like so (necessary for user creation):

```sudo ./mcsrv-script.bash -install```

The script will create a new non-sudo enabled user from wich the game server will run. If you want to have multiple game servers on the same machine just run the script multiple times but with a diffrent username inputted to the script.

Copy your game files to the server folder in the created user's home folder.

After the installation finishes you can reboot the operating system and the service files will start the game server automaticly on boot.

You can also install bash aliases to make your life easier with the following command:

```./mcsrv-script.bash -install_aliases```

After that relog.

Any other script commands are available with:

```./mcsrv-script.bash -help```

That should be it.

**Known issues are:**

-none at the moment
