#!/bin/bash

# PrimeMover.io

# Universal WordPress VPS Migration Assistant

# Copyright 2018 PrimeMover.io - K. Patrick Gallagher

# Easily move WordPress sites between two different servers managed by GridPane, ServerPilot, RunCloud and Others...

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root, exiting!!!" 
   exit 1
fi

# Check is PV is installed, and install if needed...
if ! type "pv" > /dev/null; then
	echo "PV was not installed... fixing..."
  	apt -y install pv
fi

mkdir -p /var/tmp/primemover

ipaddress=$(curl http://ip4.ident.me 2>/dev/null)

MeImCounting() {
	
	echo "This is all very VERY aplha right now. Use at your own risk."
	echo " "
	echo "All kinds of things might be broken. It's a work in progress and we'll get it hammered out shortly."
	echo " "
	echo "Please feel free to help out."
	echo " "
	echo "Best of luck! Drop me a line at patrick at gridpane dot com"
	echo " "
	echo "You need to have already created SSH keys on both your source server and your destination server and shared them between the two."
	echo " "
	echo "This all automatically works if you're using GridPane because we (try, at least, to) kick all of the asses."

}
MeImCounting

CommandVariablesCheck() {
	
	# Checking correct startup variables
	if [ -z "$1" ] || [ -z "$2" ] 
	then
		echo " "
		echo " "
		echo "   ***************************************"
		echo "*******   ERROR - MISSING VARIABLES   *******"
		echo "   ***************************************"
		echo " "
		echo " "
		echo "Command line variables required: "
		echo " "
		echo " 1.) URL/ALL "
		echo " 2.) Target IP address "
		echo " 3.) *OPTIONAL* Source API token (GridPane servers only - ServerPilot and RunCloud API support coming soon) " 
		echo " 4.) *OPTIONAL* Target API token (GridPane servers only - ServerPilot and RunCloud API support coming soon) "
	
		# LOTS of work needs to be added in here to make this work seamlessly between SP and RC nodes, and between RC and RC, and between SP and SP, and... you get the point.
		echo " "
		echo " "
		exit 187;
	
	else
		# Set all the primary variables - Additional Variables - REQUIRED - But we'll get these soon... appname username finaldomain
		site_to_clone=$1
		remote_IP=$2	
		sourcetoken=$3
		targettoken=$3
	fi

}

# Install WP-CLI - Makes everything so much easier!!!
CheckWPcli() {
	
	if [ -f /usr/local/bin/wp ]
	then
		echo "WP-CLI is already installed, making sure it's the most current version..."
		yes | wp cli update --allow-root
	else
		curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
		chmod +x wp-cli.phar
		sudo mv wp-cli.phar /usr/local/bin/wp
	fi

}
CheckWPcli

ServerPilotShell() {
	
	#Check if ServerPilot API is Installed...
	if [ -f "/usr/local/bin/serverpilot" ]
	then
		echo "ServerPilot API Already Installed!"
		sed -i 's/printf "%-20s"/printf "%-30s"/g' /usr/local/bin/serverpilot #Fixes the column bleed issue...Just making sure here!
		source ~/.bash_profile
	else
		#install jq
		sudo apt-get -y install jq
		curl -sSL https://raw.githubusercontent.com/kodie/serverpilot-shell/master/lib/serverpilot.sh > /usr/local/bin/serverpilot 
		chmod a+x /usr/local/bin/serverpilot
		sed -i 's/printf "%-20s"/printf "%-25s"/g' /usr/local/bin/serverpilot #Fixes the column bleed issue...
		echo "Enter ClientID from ServerPilot Account..."
		read clientID
		echo "Enter API Key from ServerPilot Account..."
		read APIkey
		printf '\nexport serverpilot_client_id="'$clientID'"\nexport serverpilot_api_key="'$APIkey'"' >> ~/.bash_profile && source ~/.bash_profile
	fi

}


# Check is SSH key present, if not make it so... This currently only applies to migrating IN to GridPane servers... 
# Disabled by default because while I may be a total egotistical prick I recognize that you're MUCH more likely to be running on a SP or RC node than a GridPane managed box.

DoSSHForGridPane() {
	
	if [ "$y" = "1" ]
	then
		echo "An error was detected during a previous function, skipping the site packaging step for this site..."
		return 1
	fi
	
	ipaddress=$(curl http://ip4.ident.me 2>/dev/null)
	
	if [ -f /root/.ssh/id_rsa.pub ]
	then
		echo "Local SSH Keys exist..." 
		echo ""
		
	else
		echo "We need to create a public key pair..." 
		echo "CREATING SSH!!!" 
		
		#echo -e "\n\n\n" | ssh-keygen -t rsa -b 4096
		ssh-keygen -t rsa -b 4096 -N "" -f /root/.ssh/id_rsa
		
	fi
	
	sshcheck=$(ssh-keygen -F $remote_IP 2>&1)
	
	if [ $? -eq 0 ]
	then
		echo "Remote host is already in the Known Hosts file..."
		echo ""
	else
		ssh-keyscan $remote_IP >> /root/.ssh/known_hosts
		curl -F "ssh_key=@/root/.ssh/id_rsa.pub" -F "source_ip=$ipaddress" -F "failover_ip=$remote_IP" https://my.gridpane.com/api/pair-external-servers?api_token=$gridpanetoken
		echo "Remote host added to the Known Hosts file..." 
		echo ""
	fi
	
	sshtatus=$(ssh -o BatchMode=yes -o ConnectTimeout=5 $remote_IP echo ok 2>&1)
	
	if [ $sshtatus == "ok" ]
	then
		echo "Remote SSH Test Successful..." 
	else
		echo "Establishing remote connection to target..." 
		curl -F "ssh_key=@/root/.ssh/id_rsa.pub" -F "source_ip=$ipaddress" -F "failover_ip=$remote_IP" https://my.gridpane.com/api/pair-external-servers?api_token=$gridpanetoken
	fi

}
#DoSSHForGridPane

SSHKeyShare() {
	
	# This allows the user to do a SSH key exchange from the current server to their target...
	
	ssh-copy-id -i ~/.ssh/id_rsa.pub root@$remoteIP

}

# Old Original MoveWP Code... Needs LOTS o' work!

MoveTHISHere() {
	
	# Moves a site from the local directory to... elsewhere
	
	currentdirectory=$(pwd)
	echo "Current Working Directory is... $currentdirectory"

	if [ -f wp-config.php ]
	then
	
		#Get all of the remote server details...
		echo "Enter remote Server IP Address..."
		read remoteIP
		echo "Enter Remote Username"
		read remoteUser
		echo "Enter Remote WP Site Folder..."
		read remoteFolder
		#echo "Enter Remote Password..." (We're not doing password shit...)
		#read remotePass
	
		# Export the Database
		wp db export database.sql --allow-root
		chmod 600 database.sql
		echo "DB Exported..."
	
		#Need to get the DB prefix from wp-config... 
		tableprefix=$(sed -n -e '/$table_prefix/p' wp-config.php)
		echo $tableprefix > table.prefix
		echo "Database Prefix Exported..."
	
		# Tar everything up
		echo "Creating Compressed Tarball of entire site... PLEASE WAIT!!!"
		#tar -czf ../wp-migrate-file.gz . --exclude '*.zip' --exclude '*.gz' --exclude 'wp-config.php'
		tar -cf - . -P --exclude '*.zip' --exclude '*.gz' --exclude 'wp-config.php' | pv -s $(du -sb . | awk '{print $1}') | gzip > ../wp-migrate-file.gz
	
		chmod 600 ../wp-migrate-file.gz
		
		rm database.sql
	
		rm table.prefix

		echo "Complete Wordpress Site Backed Up"
	
		# Copy things to the remote server...
	
		ssh-keyscan $remoteIP >> ~/.ssh/known_hosts
	
		sshpass -p "$remotePass" ssh-copy-id $remoteUser@$remoteIP
	
		sleep 2
	
		echo "Copying Compressed Migration File to Remote Server"
	
		echo "Please wait..."
	
		#sshpass -p "$remotePass" scp -o StrictHostKeyChecking=no ../wp-migrate-file.gz $remoteUser@$remoteIP:$remoteFolder/wp-migrate-file.gz
	
		scp ../wp-migrate-file.gz $remoteUser@$remoteIP:$remoteFolder/wp-migrate-file.gz
	
		rm ../wp-migrate-file.gz
	
		echo "Things either worked or they didn't... but everything has been deleted so you can always try again."
	
		# You could run restoreWP on the remote server... assuming it's there...
	
		echo "Do you want to run restoreWP on the remote server? - Press enter for Yes... Any input for No"
	
		read DoRestore
	
		if [ -z $DoRestore ]
		then
			echo "Running remote restoration process..."
			sshpass -p "$remotePass" ssh $remoteUser@$remoteIP "sleep 2 && cd $remoteFolder && restoreWP" # THIS WILL FAIL BECAUSE THEY DON'T HAVE restoreWP !!!!
			echo "Remote restoration... done???"
		fi
	
		echo "Done and done."
	
	else
		echo "This is not a Wordpress Directory... try again."
	fi

}


OLDDISPOSABLESPCODE() {
	
  awk '/server_name/,/;/' /etc/nginx-sp/vhosts.d/$appname.conf > /var/tmp/primemover/current-domains.txt
  sed -i '/server_name/d' /var/tmp/primemover/current-domains.txt
  sed -i '/server-/d' /var/tmp/primemover/current-domains.txt
  sed -i '/www./d' /var/tmp/primemover/current-domains.txt
  sed -i '/;/d' /var/tmp/primemover/current-domains.txt
  awk '!a[$0]++' /var/tmp/primemover/current-domains.txt > /var/tmp/primemover/final-domains.txt
  sed -i "s/ //g" /var/tmp/primemover/final-domains.txt
  #echo "The Final List of domains for this application in text form is..."
  #cat /var/tmp/primemover/final-domains.txt
  appdomain=$(awk '{print $1}' /var/tmp/primemover/final-domains.txt)
  appdomain=$(echo $appdomain|tr -d '\n')

}

GetSPUserAppDetails() {
	
	appholder=word$appnameCOL
	appname=$(echo ${!appholder})

	runholder=word$runtimeCOL
	php=$(echo ${!runholder})

	appidhold=word$appidCOL
	appid=$(echo ${!appidhold})

	serverhold=word$serveridCOL
	serverid=$(echo ${!serverhold})

	datehold=word$datecreatedCOL
	datecreated=$(echo ${!datehold})

	userhold=word$sysuserCOL
	sysuserid=$(echo ${!userhold})

	echo "Application Name/Folder is $appname"
	echo "PHP Version is $php"
	echo "User ID is $sysuserid"
	serverpilot sysusers $sysuserid > /var/tmp/primemover/source-user-name.txt

	serverCOL=$(awk -v name='serverid' '{for (i=1;i<=NF;i++) if ($i==name) print i; exit}' /var/tmp/primemover/source-user-name.txt)
	#echo "serverid Column is $serverCOL"

	usernameCOL=$(awk -v name='name' '{for (i=1;i<=NF;i++) if ($i==name) print i; exit}' /var/tmp/primemover/source-user-name.txt)
	#echo "UserName Column is $usernameCOL"

	userIDCOL=$(awk -v name='id' '{for (i=1;i<=NF;i++) if ($i==name) print i; exit}' /var/tmp/primemover/source-user-name.txt)
	#echo "UserID Column is $userIDCOL"

	sed '1d' /var/tmp/primemover/source-user-name.txt > /var/tmp/primemover/tmpfile; mv /var/tmp/primemover/tmpfile /var/tmp/primemover/source-user-name.txt

	if [ $usernameCOL -eq 1 ] 
	then
		currentuser=$(awk '{print $1}' /var/tmp/primemover/source-user-name.txt)
	elif [ $usernameCOL -eq 2 ]
	then
		currentuser=$(awk '{print $2}' /var/tmp/primemover/source-user-name.txt)
	else
		currentuser=$(awk '{print $3}' /var/tmp/primemover/source-user-name.txt)
	fi

	currentuser=$(echo $currentuser|tr -d '\n')
	echo "System User Name for this App is $currentuser"

}


SPtoSP() {
	
	envir=SP
	
	admin_user=WZRD
	
	admin_password=P@55W0RD12345
	
	admin_email=info@wzrd.co
	
	# The intention here is to move sites from a ServerPilot node to another ServerPilot node

	# THIS IS ALL CURRENTLY UNDER CONSTRUCTION - THIS IS ALL CODE THAT NEEDS TO BE UPDATED TO WORK FOR PRIMEMOVER
	# This should all be retooled to just use variables but for now it works with temporary text files 
	
	serverpilot servers > /var/tmp/primemover/server-list.txt

	echo "Here's our raw SP Server details for all connected nodes..."

	cat /var/tmp/primemover/server-list.txt

	serverCOL=$(awk -v name='name' '{for (i=1;i<=NF;i++) if ($i==name) print i; exit}' /var/tmp/primemover/server-list.txt)
	#echo "Server Column is located: Column $serverCOL..."

	ipaddressCOL=$(awk -v name='lastaddress' '{for (i=1;i<=NF;i++) if ($i==name) print i; exit}' /var/tmp/primemover/server-list.txt)
	#echo "IP Address Column is located: Column $ipaddressCOL..."
	
	idCOL=$(awk -v name='id' '{for (i=1;i<=NF;i++) if ($i==name) print i; exit}' /var/tmp/primemover/server-list.txt)
	#echo "ID Column is located: Column $idCOL..."

	awk -v col=name 'NR==1{for(i=1;i<=NF;i++){if($i==col){c=i;break}} print $c} NR>1{print $c}' /var/tmp/primemover/server-list.txt > /var/tmp/primemover/server-names.txt

	awk -v col=lastaddress 'NR==1{for(i=1;i<=NF;i++){if($i==col){c=i;break}} print $c} NR>1{print $c}' /var/tmp/primemover/server-list.txt > /var/tmp/primemover/server-ips.txt

	awk -v col=id 'NR==1{for(i=1;i<=NF;i++){if($i==col){c=i;break}} print $c} NR>1{print $c}' /var/tmp/primemover/server-list.txt > /var/tmp/primemover/server-ids.txt
	
	
	echo "Please keep in mind: THIS CAN POTENTIALLY BE DESTRUCTIVE!!!"
	echo ""
	echo ""
	echo "###########################################################"
	echo "########  Beginning Migration and Provisioning... #########"
	echo "########      Here are your available Servers     #########"
	echo "###########################################################"
	echo ""
	echo ""
	rownumber=0
	cp /var/tmp/primemover/server-names.txt /var/tmp/primemover/server-names.tmp
	sed -i -e "1d" /var/tmp/primemover/server-names.tmp
	sed -i -e "1d" /var/tmp/primemover/server-ips.txt 
	sed -i -e "1d" /var/tmp/primemover/server-ids.txt
	while IFS=" " read -r entrydetail
	do
		rownumber=$((rownumber+1))
		currentIP=$(cat /var/tmp/primemover/server-ips.txt | awk '{print $"$ipaddressCOL"; exit}')
		currentID=$(cat /var/tmp/primemover/server-ids.txt | awk '{print $"$idCOL"; exit}')
		if [[ $currentIP == $ipaddress ]]
		then 
			
			#Don't display this machine... it's obviously the source. 
			sourcerow=$((rownumber+1))
			sourceserver=$entrydetail
			sourceID=$currentID
			sourceIP=$currentIP
			
		else
			
			echo "Server #$rownumber ... Named: $entrydetail ...	with IP Address of $currentIP"
		
		fi
		
		sed -i -e "1d" /var/tmp/primemover/server-ips.txt 

	done < "/var/tmp/primemover/server-names.tmp"
	echo ""
	echo "Enter Target Server By Number..."
	read targetServer

	#targetServer=$((targetServer+1)) #Increment the server line number by 1 to accomodate the heading line within the source output

	serveridsource=$(cat /var/tmp/primemover/server-ids.txt)

	servernames=$(cat /var/tmp/primemover/server-names.txt)

	targetID=$(echo "$serveridsource" | sed -n "$targetServer"p)
	targetIP=$(serverpilot find servers id=$targetID lastaddress)
	echo ""
	echo ""
	echo "The target server has an ID of... $targetID... with IP Address $targetIP"
	echo ""
	echo "The source server has an ID of... $sourceID... with IP Address $sourceIP"
	echo ""
	echo "These are all of the Source Applications on $sourceserver..."
	echo ""
	serverpilot find apps serverid=$(serverpilot find servers name=$sourceserver id) > /var/tmp/primemover/source-applications.txt

	cat /var/tmp/primemover/source-applications.txt

	sysuserCOL=$(awk -v name='sysuserid' '{for (i=1;i<=NF;i++) if ($i==name) print i; exit}' /var/tmp/primemover/source-applications.txt)

	runtimeCOL=$(awk -v name='runtime' '{for (i=1;i<=NF;i++) if ($i==name) print i; exit}' /var/tmp/primemover/source-applications.txt)

	appnameCOL=$(awk -v name='name' '{for (i=1;i<=NF;i++) if ($i==name) print i; exit}' /var/tmp/primemover/source-applications.txt)

	serveridCOL=$(awk -v name='serverid' '{for (i=1;i<=NF;i++) if ($i==name) print i; exit}' /var/tmp/primemover/source-applications.txt)

	datecreatedCOL=$(awk -v name='name' '{for (i=1;i<=NF;i++) if ($i==name) print i; exit}' /var/tmp/primemover/source-applications.txt)

	appidCOL=$(awk -v name='id' '{for (i=1;i<=NF;i++) if ($i==name) print i; exit}' /var/tmp/primemover/source-applications.txt)

	# echo "systemuserid Column: $sysuserCOL - runtime Column: $runtimeCOL - AppName Column: $appnameCOL - ServerID Column: $serveridCOL - Date Column: $datecreatedCOL - AppID Column is $appidCOL"

	echo ""
	echo "To begin initializing ALL apps press ENTER... NOTE: User passwords will be reset on target node!"

	read desiredapps

	if [ -z "$desiredapps" ]
	then
		sed '1d' /var/tmp/primemover/source-applications.txt > /var/tmp/primemover/tmpfile; mv /var/tmp/primemover/tmpfile /var/tmp/primemover/source-applications.txt
		echo "Copying SP Sites..."
		while IFS=" " read -r word1 word2 word3 word4 word5 word6
		do
		  
			GetSPUserAppDetails
		  
			cd /srv/users/$currentuser/apps/$appname/public
		  
			if ! $(wp core is-installed --allow-root); 
			then
		  	  
				echo "This is not a valid WordPress install, skipping this app!"

			else
			  
				echo "Proceeding..."
			  
				SingleSPDomain
			  
				echo "The Final Domain for this application is $finaldomain"
				
				appdomain=$finaldomain
			  
				echo "Creating New System User $currentuser on Target Server $targetserver..."
			  
				if [[ $currentuser == "serverpilot" ]]
				then
					echo "Default serverpilot user already exists on remote system..."
					serverpilot find sysusers serverid=$targetID > /var/tmp/primemover/new-server-users.txt
					sed -r -n -e /$currentuser/p /var/tmp/primemover/new-server-users.txt > /var/tmp/primemover/new-user-details.txt

					newuserIDCOL=$(awk -v name='id' '{for (i=1;i<=NF;i++) if ($i==name) print i; exit}' /var/tmp/primemover/new-server-users.txt)
					#echo "New User ID Column is $newuserIDCOL"

					if [ $newuserIDCOL -eq 1 ] 
					then
						newuserID=$(awk '{print $1}' /var/tmp/primemover/new-user-details.txt)
					elif [ $newuserIDCOL -eq 2 ]
					then
						newuserID=$(awk '{print $2}' /var/tmp/primemover/new-user-details.txt)
					else
						newuserID=$(awk '{print $3}' /var/tmp/primemover/new-user-details.txt)
					fi
				else
					echo "Creating new user $currentuser on remote system..."
				  
					serverpilot sysusers create $targetID $currentuser
					serverpilot find sysusers serverid=$targetID > /var/tmp/primemover/new-server-users.txt
					sed -r -n -e /$currentuser/p /var/tmp/primemover/new-server-users.txt > /var/tmp/primemover/new-user-details.txt

					newuserIDCOL=$(awk -v name='id' '{for (i=1;i<=NF;i++) if ($i==name) print i; exit}' /var/tmp/primemover/new-server-users.txt)
					#echo "New User ID Column is $newuserIDCOL"

					if [ $newuserIDCOL -eq 1 ] 
					then
						newuserID=$(awk '{print $1}' /var/tmp/primemover/new-user-details.txt)
					elif [ $newuserIDCOL -eq 2 ]
					then
						newuserID=$(awk '{print $2}' /var/tmp/primemover/new-user-details.txt)
					else
						newuserID=$(awk '{print $3}' /var/tmp/primemover/new-user-details.txt)
					fi

					randpass=$(openssl rand -base64 12)
					echo "New User $currentuser on Server $targetserver has ID $newuserID"
					serverpilot sysusers update $newuserID password $randpass
					echo "... and now has new random password $randpass"
				fi
	
				echo "Packaging up site..."
				
				#TARBALL THE SITE
				
				PackageSite
		
				serverpilot apps create $appname $newuserID $php '["'$appdomain'","www.'$appdomain'"]' '{"site_title":"'$appname'","admin_user":"'$admin_user'","admin_password":"'$admin_password'","admin_email":"'$admin_email'"}'

				echo "Waiting for remote site build to complete..." #Add error checking here by routing that ^^^ output to a variable and checking it
				
				sleep 5
			  
				scp /srv/users/$username/apps/$appname/primemover-$appname-migration-file.gz root@$targetIP:/srv/users/$username/apps/$appname/primemover-$appname-migration-file.gz
				
				sleep 1
			  
				echo "Running remote restoration process..."

				#ssh root@$targetIP "sleep 3 && tar -xzf /srv/users/$username/apps/$appname/primemover-$appname-migration-file.gz -C /srv/users/$username/apps/$appname/public/ --overwrite && cd /srv/users/$username/apps/$appname/public/ && tableprefix=$(cat /srv/users/$username/apps/$appname/public/table.prefix) && sed -i "/$table_prefix =/c\\$tableprefix" /srv/users/$username/apps/$appname/public/wp-config.php && wp db import database.sql --allow-root && rm database.gz && rm table.prefix && chown -R $username:$username /srv/users/$username/apps/$appname/public/* && /srv/users/$username/apps/$appname/primemover-$appname-migration-file.gz"
				
				ssh root@$targetIP "sleep 3 && wget https://github.com/gridpane/prime-mover/archive/master.zip && unzip master.zip && mv prime-mover-master/primemover.sh /usr/local/bin/primemover && chmod +x /usr/local/bin/primemover && sleep 1 && tar -xzf /srv/users/$username/apps/$appname/primemover-$appname-migration-file.gz -C /srv/users/$username/apps/$appname/public/ --overwrite && cd /srv/users/$username/apps/$appname/public && primemover restore"
				
				sleep 5 
				
				echo "Remote restoration done... right?"
		
			fi
		
		done < "/var/tmp/primemover/source-applications.txt"
		
	fi
}


MoveFromRC() {
	
	if [ -f "/etc/nginx-rc/nginx.conf" ]
	then
		echo "Copying from a RunCloud Server..."
	
		while read -r fullpath
		do
			
			# THIS IS ALL REALLY SHITTY AND REDUNDANT - GOTTA GO
			# THIS IS ALL REALLY SHITTY AND REDUNDANT - GOTTA GO
			# THIS IS ALL REALLY SHITTY AND REDUNDANT - GOTTA GO
			# THIS IS ALL REALLY SHITTY AND REDUNDANT - GOTTA GO

			file=$(basename $fullpath) # We already know this is wp-config.php because... code. 

			dir=$(dirname $fullpath) # This is where we're headed

			cd $dir # And no we're here...
	
			# And now we grab the name of the current directory "application" with this...
			appname=${PWD##*/}
	
			# Carve out the domains from the nginx config files for this WP site... somehow...
			awk '/server_name/,/;/' /etc/nginx-rc/conf.d/$appname.d/main.conf > /var/tmp/primemover/current-domains.txt
	
			#Get rid of the server_name and blank spaces business...
			sed -i 's/server_name             //g' /var/tmp/primemover/current-domains.txt 
	
			#And now get rid of anything between www and the semicolon... Keep in mind this is NOT going to be foolproof for various subdomains etc. 
			appdomain=$(sed 's/www.*;//' /var/tmp/primemover/current-domains.txt)
		
			#Gotta Settle/Fix for a subdomain use case... i.e. when there is a subdomain ONLY and a semicolon at the end!
			# Here we go... 
			#VERSION='2.3.3'...echo "${VERSION//.}" - - - With the period . . . . being the thing that gotta go. 
			appdomain=$(echo "${appdomain//;}")
	
			appdomain=$(echo $appdomain|tr -d '\n')
	
			echo "The Final List of domains for this application is $appdomain"
	
			# Now we deal with usernames... which we will extract here
		
			currentuser=$(ls -ld $fullpath | awk '{print $3}')
		
			if [ $currentuser = "runcloud" ]
			then
				echo "Current user is runcloud... not cool..."
				echo "Using root domain name to generate remote username..."
				rootdomain=$(echo $appdomain | awk -F\. '{print $(NF-1) FS $NF}')
				currentuser=${rootdomain%.*}
				echo "New Username is... $currentuser"
			fi
	
			# THIS IS ALL REALLY SHITTY AND REDUNDANT - GOTTA GO
			# THIS IS ALL REALLY SHITTY AND REDUNDANT - GOTTA GO
			# THIS IS ALL REALLY SHITTY AND REDUNDANT - GOTTA GO
			# THIS IS ALL REALLY SHITTY AND REDUNDANT - GOTTA GO
			
			# We're going to need to know the PHP version... somehow...
			# FIND PHP HERE!!!
			if [ -f "/etc/php56rc/fpm.d/$appname.conf" ]
			then
				echo "PHP56RC file found... setting PHP to verison 5.6"
				php="php5.6"
			elif [ -f "/etc/php70rc/fpm.d/$appname.conf" ]
			then
				echo "PHP70RC file found... setting PHP to verison 7.0"
				php="php7.0"
			elif [ -f "/etc/php71rc/fpm.d/$appname.conf" ]
			then
				echo "PHP71RC file found... setting PHP to verison 7.1"
				php="php7.1"
			else
				echo "No PHP file found... defaulting to PHP7.0"
				php="php7.0"
			fi

			echo "Creating New System User $currentuser on Target Server $targetserver..."
			serverpilot sysusers create $targetID $currentuser
			serverpilot find sysusers serverid=$targetID > /var/tmp/primemover/new-server-users.txt
			sed -r -n -e /$currentuser/p /var/tmp/primemover/new-server-users.txt > /var/tmp/primemover/new-user-details.txt
	
		  	newuserIDCOL=$(awk -v name='id' '{for (i=1;i<=NF;i++) if ($i==name) print i; exit}' /var/tmp/primemover/new-server-users.txt)
		  	#echo "New User ID Column is $newuserIDCOL"
	
			if [ $newuserIDCOL -eq 1 ] 
			then
				newuserID=$(awk '{print $1}' /var/tmp/primemover/new-user-details.txt)
			elif [ $newuserIDCOL -eq 2 ]
			then
				newuserID=$(awk '{print $2}' /var/tmp/primemover/new-user-details.txt)
			else
				newuserID=$(awk '{print $3}' /var/tmp/primemover/new-user-details.txt)
			fi
	
			randpass=$(openssl rand -base64 12)
			echo "New User $currentuser on Server $targetserver has ID $newuserID"
			serverpilot sysusers update $newuserID password $randpass
			echo "... and now has new random password $randpass"

			echo "Copy WP Site with WWW Domain..."
			# Export the Database
			wp db export database.sql --allow-root
			chmod 600 database.sql
			echo "DB Exported..."

			#Need to get the DB prefix from wp-config... 
			tableprefix=$(sed -n -e '/$table_prefix/p' wp-config.php)
			echo $tableprefix > table.prefix
			echo "Database Prefix Exported..."

			# Tar everything up
			echo "Creating Compressed Tarball of entire site... PLEASE WAIT!!!"
			#tar -czf ../wp-migrate-file.gz . --exclude '*.zip' --exclude '*.gz' --exclude 'wp-config.php'
			tar -cf - . -P --exclude '*.zip' --exclude '*.gz' --exclude 'wp-config.php' | pv -s $(du -sb . | awk '{print $1}') | gzip > ../wp-migrate-file.gz
			sleep 2
			echo "Compressed Tarball is Ready to Ship..."
			rm database.sql
			rm table.prefix
			echo "Exported SQL File Deleted..."
	
			#Make sure we don't have any underscores...
			echo $appname > tempfile
			appname=$(sed 's/\_/-/g' tempfile)
			rm tempfile
	
			serverpilot apps create $appname $newuserID $php '["'$appdomain'","www.'$appdomain'"]' '{"site_title":"'$appname'","admin_user":"WZRD","admin_password":"P@55W0RD12345","admin_email":"info@wzrd.co"}'
			sleep 1
			echo "Remote Application Step Completed... or did it?"
			ssh-keyscan $targetIP >> ~/.ssh/known_hosts
			sshpass -p "$randpass" ssh-copy-id $currentuser@$targetIP
			scp ../wp-migrate-file.gz $currentuser@$targetIP:/srv/users/$currentuser/apps/$appname/public/wp-migrate-file.gz
			sleep 2
		
			echo "Running remote restoration process..."
			sshpass -p "$randpass" ssh $currentuser@$targetIP "sleep 2 && cd /srv/users/$currentuser/apps/$appname/public && restoreWP" < /dev/null # This dev/null - I *believe* fixed the problem with only one line being processed
			echo "Remote restoration... done???"
		
			echo "This was the fullpath we just completed... $fullpath."
		
			echo "Continuing..."
		
			# Try to store all these details...
			if [ -z $setClone ]
			then
				echo "We're gonna write these details to the spot now..."
			
				echo -e $dir $targetIP $currentuser $appname $newuserID $appdomain >> /root/cloneserver.lock

				echo "What we do next with them... is entirely up to you!"
			fi
		done <"/var/tmp/primemover/wp-sites.txt"
	fi
}

StartDomainLogging() {
	
	if [ -f /var/tmp/primemover.domains.tmp ]
	then
		rm /var/tmp/primemover.domains.tmp
	fi
	touch /var/tmp/primemover.domains.tmp

	echo ""
	echo "The following sites have been located on this server..."
	echo "************************************************************************************************************************"
	printf '%-20s %-40s %-20s %-30s %-30s\n' "APPLICATION" "DOMAIN" "USER" "LOCATION"
	echo "************************************************************************************************************************"
	
}

SingleRCDomain() {
	
	sourcedomain=$(awk '/server_name/,/;/' /etc/nginx-rc/conf.d/$appname.d/main.conf)
	sourcedomain=$(echo "$sourcedomain" | sed 's/\S*\_name\S*//g')
	sourcedomain=$(echo "${sourcedomain//;}") # Drop trailing semicolon
	sourcedomain2=$(echo "$sourcedomain" | sed 's/\S*\www\S*//g')
	
	rootfolder=$(awk '/root/,/;/' /etc/nginx-rc/conf.d/$appname.d/main.conf) # Grab root folder location
	rootfolder=$(echo $rootfolder | awk '{print $2;}')
	rootfolder=$(echo "${rootfolder//;}") # Drop trailing semicolon
	
	if [ ${#sourcedomain2} -lt 4 ]
	then
		finaldomain=$sourcedomain
	else
		finaldomain=$sourcedomain2
	fi
	
	if [ ${#finaldomain} -lt 3 ]
	then
		
		printf '%-20s %-40s %-20s %-30s %-30s\n' $appname "NO DOMAIN!!!" "UNKNOWN" "$rootfolder   ****SKIPPING****"
	
	else
		if [ -d $rootfolder ]
		then
			cd $rootfolder
			cd ../..
			username=$(basename $PWD)

			domaincount=$(echo $finaldomain | wc -w)

			if [ $domaincount == "1" ]
			then
				grid=work
			else
				#echo "This site has more than one domain! We're only able to process the first URL..."
				finaldomain=$(echo $finaldomain | awk '{print $1;}')
			fi

			finaldomain=$(echo "$finaldomain" | sed "s/ //g")

			dots=$(echo "$finaldomain" | awk -F. '{ print NF - 1 }')

			if [ $dots -ge 2 ]
			then
				if [[ $finaldomain == "staging."* ]]
				then
					printf '%-20s %-40s %-20s %-30s %-30s\n' $appname "$finaldomain (STAGING)" $username $rootfolder
				else
					printf '%-20s %-40s %-20s %-30s %-30s\n' $appname "$finaldomain (SUBDOMAIN)" $username $rootfolder
				fi
			else
				printf '%-20s %-40s %-20s %-30s %-30s\n' "$appname" $finaldomain $username $rootfolder
			fi
		
			echo "$appname $finaldomain $username $rootfolder ${#finaldomain}" >> /var/tmp/primemover.domains.tmp
		
		else
			printf '%-20s %-40s %-20s %-30s %-30s\n' "$appname" $finaldomain "UNKNOWN!!!" "SITE ROOT FOLDER DAMAGED OR MISSING!   ****SKIPPING****"
		fi
	fi
	
}

rcDomains() {
	
	search_dir="/etc/nginx-rc/conf.d"
	
	StartDomainLogging

	for entry in "$search_dir"/*
	do
	
		if [[ $entry == *".conf" ]]
		then 
			# Skipping app .conf file...
			grid=work
		else
			#echo "Entry is $entry..."
			appname=$(basename $entry)
			appname=$(echo "${appname//.d}")
			SingleRCDomain
		fi
	done

	echo "************************************************************************************************************************"
	echo ""
	echo ""
	echo "PLEASE CONFIRM THIS LIST OF SITES LOOKS CORRECT... PRESS CTRL-Z to CANCEL if there is an error!!!"
	echo ""
	echo ""
	read -t 10 -n 1 -s -r -p "Press any key to confirm or wait ten seconds..." ;

sort -k5 -n /var/tmp/primemover.domains.tmp > /var/tmp/primemover.domains.tmp2

}

SingleSPDomain() {
	
	sourcedomain=$(awk '/server_name/,/;/' /etc/nginx-sp/vhosts.d/$appname.conf)
	sourcedomain=$(echo "$sourcedomain" | sed '/server_name/d')
	sourcedomain=$(echo "$sourcedomain" | sed '/server-/d')
	sourcedomain=$(echo "$sourcedomain" | sed '/;/d')
	sourcedomain=$(echo "$sourcedomain" | awk '!a[$0]++')
	sourcedomain=$(echo "$sourcedomain" | sed "s/ //g")
	sourcedomain2=$(echo "$sourcedomain" | sed '/www./d')

	rootfolder=$(awk '/root/,/;/' /etc/nginx-sp/vhosts.d/$appname.conf) # Grab root folder location
	rootfolder=$(echo "${rootfolder//;}") # Drop trailing semicolon
	rootfolder=$(echo "${rootfolder//root }") # Drop root descriptor
	
	if [ ${#sourcedomain2} -lt 4 ]
	then
		finaldomain=$sourcedomain
	else
		finaldomain=$sourcedomain2
	fi
	
	if [ ${#finaldomain} -lt 3 ]
	then
		
		printf '%-20s %-40s %-20s %-30s %-30s\n' $appname "NO DOMAIN!!!" "UNKNOWN" "$rootfolder   ****SKIPPING****"
	
	else
		if [ -d $rootfolder ]
		then
			cd $rootfolder
			cd ../../..
			username=$(basename $PWD)

			domaincount=$(echo $finaldomain | wc -w)

			if [ $domaincount == "1" ]
			then
				grid=work
			else
				#echo "This site has more than one domain! We're only able to process the first URL..."
				finaldomain=$(echo $finaldomain | awk '{print $1;}')
			fi

			finaldomain=$(echo "$finaldomain" | sed "s/ //g")

			dots=$(echo "$finaldomain" | awk -F. '{ print NF - 1 }')

			if [ $dots -ge 2 ]
			then
				if [[ $finaldomain == "staging."* ]]
				then
					printf '%-20s %-40s %-20s %-30s %-30s\n' $appname "$finaldomain (STAGING)" $username $rootfolder
				else
					printf '%-20s %-40s %-20s %-30s %-30s\n' $appname "$finaldomain (SUBDOMAIN)" $username $rootfolder
				fi
			else
				printf '%-20s %-40s %-20s %-30s %-30s\n' "$appname" $finaldomain $username $rootfolder
			fi
		
			echo "$appname $finaldomain $username $rootfolder ${#finaldomain}" >> /var/tmp/primemover.domains.tmp
		
		else
			printf '%-20s %-40s %-20s %-30s %-30s\n' "$appname" $finaldomain "UNKNOWN!!!" "SITE ROOT FOLDER DAMAGED OR MISSING!   ****SKIPPING****"
		fi
	fi
	
}

spDomains() {
	
	search_dir="/etc/nginx-sp/vhosts.d"

	StartDomainLogging

	for entry in "$search_dir"/*
	do
	
		if [[ $entry != *".conf" ]]
		then 
			grid=work
		else
			appname=$(basename $entry)
			appname=$(echo "${appname//.conf}")
			SingleSPDomain
		fi
	done

	echo "************************************************************************************************************************"
	echo ""
	echo ""
	echo "PLEASE CONFIRM THIS LIST OF SITES LOOKS CORRECT... PRESS CTRL-Z to CANCEL if there is an error!!!"
	echo ""
	echo ""
	read -t 10 -n 1 -s -r -p "Press any key to confirm or wait ten seconds..." ;


sort -k5 -n /var/tmp/primemover.domains.tmp > /var/tmp/primemover.domains.tmp2

}

cpDomains() {
	
	search_dir="/home"

	StartDomainLogging

	for entry in "$search_dir"/*
	do
	
		if [[ -d "$entry"/etc ]]
		then 
			cd $entry/etc/*/
			appname=$(basename $PWD)
			
			SingleCPDomain
		else
			echo "This doesn't appear to be a live Apache site..."
		fi
	done

	echo "************************************************************************************************************************"
	echo ""
	echo ""
	echo "PLEASE CONFIRM THIS LIST OF SITES LOOKS CORRECT... PRESS CTRL-Z to CANCEL if there is an error!!!"
	echo ""
	echo ""
	read -t 10 -n 1 -s -r -p "Press any key to confirm or wait ten seconds..." ;


sort -k5 -n /var/tmp/primemover.domains.tmp > /var/tmp/primemover.domains.tmp2

}

SingleCPDomain() {
	
	sourcedomain="$appname"

	rootfolder="$entry/public_html/" # Grab root folder location
	
	finaldomain="$appname"
	
	if [ ${#finaldomain} -lt 3 ]
	then
		
		printf '%-20s %-40s %-20s %-30s %-30s\n' $appname "NO DOMAIN!!!" "UNKNOWN" "$rootfolder   ****SKIPPING****"
	
	else
		if [ -d $rootfolder ]
		then
			cd $rootfolder
			cd ..
			username=$(basename $PWD)

			dots=$(echo "$finaldomain" | awk -F. '{ print NF - 1 }')

			if [ $dots -ge 2 ]
			then
				if [[ $finaldomain == "staging."* ]]
				then
					printf '%-20s %-40s %-20s %-30s %-30s\n' $appname "$finaldomain (STAGING)" $username $rootfolder
				else
					printf '%-20s %-40s %-20s %-30s %-30s\n' $appname "$finaldomain (SUBDOMAIN)" $username $rootfolder
				fi
			else
				printf '%-20s %-40s %-20s %-30s %-30s\n' "$appname" $finaldomain $username $rootfolder
			fi
		
			echo "$appname $finaldomain $username $rootfolder ${#finaldomain}" >> /var/tmp/primemover.domains.tmp
		
		else
			printf '%-20s %-40s %-20s %-30s %-30s\n' "$appname" $finaldomain "UNKNOWN!!!" "SITE ROOT FOLDER DAMAGED OR MISSING!   ****SKIPPING****"
		fi
	fi
	
}

SingleGPDomain() {
	
	sourcedomain=$(awk '/server_name/,/;/' /etc/nginx/sites-available/$appname)
	sourcedomain=$(echo "${sourcedomain//;}") # Drop trailing semicolon
	finaldomain=$(echo $sourcedomain | awk '{ $1=""; print}')
	domaincount=$(echo $finaldomain | wc -w)

	if [ $domaincount == "1" ]
	then
		grid=work
	else
		#echo "This site has more than one domain! We're only able to process the first URL..."
		finaldomain=$(echo $finaldomain | awk '{print $1;}')
	fi

	rootfolder="/var/www/$appname/htdocs"
	username="www-data"

	if [ ${#finaldomain} -lt 3 ]
	then
	
		printf '%-20s %-40s %-20s %-30s %-30s\n' $appname "NO DOMAIN!!!" "UNKNOWN" "$rootfolder   ****SKIPPING****"

	else
		if [ -d $rootfolder ]
		then
		
			domaincount=$(echo $finaldomain | wc -w)

			if [ $domaincount == "1" ]
			then
				grid=work
			else
				#echo "This site has more than one domain! We're only able to process the first URL..."
				finaldomain=$(echo $finaldomain | awk '{print $1;}')
			fi

			finaldomain=$(echo "$finaldomain" | sed "s/ //g")

			dots=$(echo "$finaldomain" | awk -F. '{ print NF - 1 }')

			if [ $dots -ge 2 ]
			then
				if [[ $finaldomain == "staging."* ]]
				then
					printf '%-20s %-40s %-20s %-30s %-30s\n' $appname "$finaldomain (STAGING)" $username $rootfolder
				else
					printf '%-20s %-40s %-20s %-30s %-30s\n' $appname "$finaldomain (SUBDOMAIN)" $username $rootfolder
				fi
			else
				printf '%-20s %-40s %-20s %-30s %-30s\n' "$appname" $finaldomain $username $rootfolder
			fi
	
			echo "$appname $finaldomain $username $rootfolder ${#finaldomain}" >> /var/tmp/primemover.domains.tmp
	
		else
			printf '%-20s %-40s %-20s %-30s %-30s\n' "$appname" $finaldomain "UNKNOWN!!!" "SITE ROOT FOLDER DAMAGED OR MISSING!   ****SKIPPING****"
		fi
	fi	
	
}

gpDomains() {
	
	search_dir="/etc/nginx/sites-available"

	StartDomainLogging

	for entry in "$search_dir"/*
	do
		#echo "Entry is $entry..."
		appname=$(basename $entry)
		#echo "Application located: $appname..."
		if [ $appname == "22222" ] || [ $appname == "default" ]
		then
			grid=work
		else
			SingleGPDomain
		fi
		
	done

	echo "************************************************************************************************************************"
	echo ""
	echo ""
	echo "PLEASE CONFIRM THIS LIST OF SITES LOOKS CORRECT... PRESS CTRL-Z to CANCEL if there is an error!!!"
	echo ""
	echo ""
	read -t 10 -n 1 -s -r -p "Press any key to confirm or wait ten seconds..." ;


sort -k5 -n /var/tmp/primemover.domains.tmp > /var/tmp/primemover.domains.tmp2

}

# Build required site(s) on remote GridPane server 
# Currently works only with GridPane... cool your jets, I'm working on it.

# You'll need to already have manually built your sites at RunCloud and have WordPress successfully running there BEFORE trying to move sites in from other sources.
# ServerPilot site build code (via API) is already built but needs to be reintegrated to this work. 

MakeSiteonRemote() {
	
	if [ "$y" = "1" ]
	then
		echo "An error was detected during a previous function, skipping the remote site build step for this site..."
		return 1
	fi
	
	if ssh -n root@$remote_IP [ -d /var/www/$site_to_clone/htdocs/wp-content/plugins/nginx-helper ] 
	then
		echo "****************************************************************************"
		echo "***** SITE ALREADY EXISTINGS ON REMOTE - PROCEDING WILL BE DESTRUCTIVE *****"
		echo "****************************************************************************"
		echo ""
		echo ""
		echo "You must press Y (Case Sensitive) to Proceed"		
		echo "Otherwise in ten seconds this site migration will be automatically halted..."
		read -t 10 -n 1 -s -r -p "Press Y to continue, anything else will halt this migration!" < /dev/tty
		
		if [[ $REPLY =~ ^[Y]$ ]]
		then
		    echo "Proceeding with potentially destructive migration!!!"
			return 0
		fi
		
		exit 187;
		
	fi

	if [ $envir == "GP" ]
	then
		echo "Checking for staging and canary sites..."
		if [[ -d "/var/www/staging.$site_to_clone"  && -d "/var/www/canary.$site_to_clone" ]]
		then
		
			echo "Site $site_to_clone has staging and updates, building three remote sites on $remote_IP..."
		
			gpcurl=$(curl -d '{"server_ip":"'$remote_IP'", "source_ip":"'$remote_IP'", "url":"'$site_to_clone'", "checkedOptions":["wpfc","php7"], "checkedAdvancedOptions":["staging", "canary"]}' -H "Content-Type: application/json" -X POST https://my.gridpane.com/api/add-site?api_token=$gridpanetoken 2>&1)
			
	
		elif [ -d "/var/www/staging.$site_to_clone" ]
		then
		
			echo "Site $site_to_clone has a staging area, building two remote sites on $remote_IP..."
		
			gpcurl=$(curl -d '{"server_ip":"'$remote_IP'", "source_ip":"'$remote_IP'", "url":"'$site_to_clone'", "checkedOptions":["wpfc","php7"], "checkedAdvancedOptions":["staging"]}' -H "Content-Type: application/json" -X POST https://my.gridpane.com/api/add-site?api_token=$gridpanetoken 2>&1)
			
		elif [ -d "/var/www/canary.$site_to_clone" ]
		then
		
			echo "Site $site_to_clone has automatic updates, building two remote sites on $remote_IP..."
		
			gpcurl=$(curl -d '{"server_ip":"'$remote_IP'", "source_ip":"'$remote_IP'", "url":"'$site_to_clone'", "checkedOptions":["wpfc","php7"], "checkedAdvancedOptions":["canary"]}' -H "Content-Type: application/json" -X POST https://my.gridpane.com/api/add-site?api_token=$gridpanetoken 2>&1)
			
		else
		
			echo "Site $site_to_clone has no staging or updates, building one remote site on $remote_IP..."
		
			gpcurl=$(curl -d '{"server_ip":"'$remote_IP'",  "source_ip":"'$remote_IP'", "url":"'$site_to_clone'", "checkedOptions":["wpfc", "php7"]}' -H "Content-Type: application/json" -X POST https://my.gridpane.com/api/add-site?api_token=$gridpanetoken 2>&1)
			
		fi
	else
		echo "Building site $site_to_clone with staging and canary updates on remote GridPane server $remote_IP..."
		
		gpcurl=$(curl -d '{"server_ip":"'$remote_IP'", "source_ip":"'$remote_IP'", "url":"'$site_to_clone'", "checkedOptions":["wpfc","php7"], "checkedAdvancedOptions":["staging", "canary"]}' -H "Content-Type: application/json" -X POST https://my.gridpane.com/api/add-site?api_token=$gridpanetoken 2>&1)
	fi
	
	echo "Waiting on remote server build..."
	sleep 3

}

DBExport() {
	
	if [ "$y" = "1" ]
	then
		echo "An error was detected during a previous function, skipping the site packaging step for this site..."
		return 1
	fi
	
	echo "Exporting Database..."
	export=$(wp db export database.sql --allow-root 2>&1)
	
	if [[ $export == *"PHP Parse error"* ]]
	then
		echo "We have a config problem and WP-CLI can't run - attempting manual mysqldump..."
		WPDBNAME=`cat wp-config.php | grep DB_NAME | cut -d \' -f 4`
		WPDBUSER=`cat wp-config.php | grep DB_USER | cut -d \' -f 4`
		WPDBPASS=`cat wp-config.php | grep DB_PASSWORD | cut -d \' -f 4`
		mysqldump -u$WPDBUSER -p$WPDBPASS $WPDBNAME > database.sql
		
	else
		echo "Automated DB export appear to throw any errors, double checking..."
	fi
	
	if [ -f database.sql ]
	then
		echo "DB Exported successfully..."
	else
		echo "Database failed to export through either method... this site will fail!!!"
		return 1
	fi

	chmod 400 database.sql
}

# Compress and package current site for secure copying

PackageSite() {
	
	if [ "$y" = "1" ]
	then
		echo "An error was detected during a previous function, skipping the site packaging step for this site..."
		return 1
	fi
	
	if [ $envir == "RC" ]
	then
		echo "Packaging local RunCloud powered site $appname for user $username..."

		cd /home/$username/webapps/$appname
		echo "Arrived at directory... $PWD"

		DBExport
		
		if [ "$y" = "1" ]
		then
			echo "An error was detected during a previous function, skipping the site packaging step for this site..."
			return 1
		fi

		#Need to get the DB prefix from wp-config... 
		tableprefix=$(sed -n -e '/$table_prefix/p' wp-config.php)
		echo $tableprefix > table.prefix
		chmod 400 table.prefix
		echo "Database Table Prefix Exported..."

		cp wp-config.php wp-config.last.config
		chmod 400 wp-config.last.config

		#tar -czf /home/$username/webapps/primemover-$appname-migration-file.gz . --exclude '*.zip' --exclude '*.gz' --exclude 'wp-config.php'
		
		tar -cf - . -P --exclude '*.zip' --exclude '*.gz' --exclude 'wp-config.php' | pv -s $(du -sb . | awk '{print $1}') | gzip > /home/$username/webapps/primemover-$appname-migration-file.gz

		echo "Cleaning up..."
		rm database.sql
		rm table.prefix
		rm wp-config.last.config
		
		echo "Site $site_to_clone has been successfully packed up..."
		
		sitepack="/home/$username/webapps/primemover-$appname-migration-file.gz"

	elif [ $envir == "SP" ]
	then
		echo "Packaging local ServerPilot powered site $appname for user $D..."
		
		# Get to the choppa...
		cd /srv/users/$username/apps/$appname/public
		echo "Arrived at directory... $PWD"
		
		DBExport
		
		if [ "$y" = "1" ]
		then
			echo "An error was detected during a previous function, skipping the site packaging step for this site..."
			return 1
		fi
		
		#Need to get the DB prefix from wp-config... 
		tableprefix=$(sed -n -e '/$table_prefix/p' wp-config.php)
		echo $tableprefix > table.prefix
		chmod 400 table.prefix
		echo "Database Table Prefix Exported..."

		cp wp-config.php wp-config.last.config
		chmod 400 wp-config.last.config

		#tar -czf /srv/users/$username/apps/$appname/primemover-$appname-migration-file.gz . --exclude '*.zip' --exclude '*.gz' --exclude 'wp-config.php'
		
		tar -cf - . -P --exclude '*.zip' --exclude '*.gz' --exclude 'wp-config.php' | pv -s $(du -sb . | awk '{print $1}') | gzip > /srv/users/$username/apps/$appname/primemover-$appname-migration-file.gz

		echo "Cleaning up..."
		rm database.sql
		rm table.prefix
		rm wp-config.last.config
		
		echo "Site $appname has been successfully packed up..."
		
		sitepack="/srv/users/$username/apps/$appname/primemover-$appname-migration-file.gz"
		
	elif [ $envir == "CP" ]
	then
		
		# HIGHLY EXPERIMENTAL!!! 
		
		echo "Packaging local CPanel powered site $appname for user $D..."
		
		# Get to the choppa...
		cd /home/$username/public_html/
		echo "Arrived at directory... $PWD"
		
		echo "Exporting DB..."
		DBExport
		
		if [ "$y" = "1" ]
		then
			echo "An error was detected during a previous function, skipping the site packaging step for this site..."
			return 1
		fi
		
		#Need to get the DB prefix from wp-config... 
		tableprefix=$(sed -n -e '/$table_prefix/p' wp-config.php)
		echo $tableprefix > table.prefix
		chmod 400 table.prefix
		echo "Database Table Prefix Exported..."

		cp wp-config.php wp-config.last.config
		chmod 400 wp-config.last.config

		#tar -czf /home/$username/public_html/primemover-$appname-migration-file.gz . --exclude '*.zip' --exclude '*.gz' --exclude 'wp-config.php'
		
		tar -cf - . -P --exclude '*.zip' --exclude '*.gz' --exclude 'wp-config.php' | pv -s $(du -sb . | awk '{print $1}') | gzip > /home/$username/public_html/primemover-$appname-migration-file.gz

		echo "Exported site pack..."
		
		echo "Cleaning up..."
		rm database.sql
		rm table.prefix
		rm wp-config.last.config
		
		echo "Site $appname has been successfully packed up..."
		
		sitepack="/home/$username/public_html/primemover-$appname-migration-file.gz"
		
	elif [ $envir == "GP" ] || [ $envir == "EE" ]
	then
		echo "Packaging local GridPane/EasyEngine compatible site $appname..."
		cd /var/www/$appname/htdocs
		echo "Arrived at directory... $PWD"
		
		DBExport
		
		if [ "$y" = "1" ]
		then
			echo "An error was detected during a previous function, skipping the site packaging step for this site..."
			return 1
		fi

		#Need to get the DB prefix from wp-config... 
		tableprefix=$(sed -n -e '/$table_prefix/p' ../wp-config.php)
		echo $tableprefix > table.prefix
		chmod 400 table.prefix
		echo "Database Table Prefix Exported..."

		cp ../wp-config.php wp-config.last.config
		chmod 400 wp-config.last.config

		#tar -czf /var/www/$appname/primemover-$appname-migration-file.gz . --exclude '*.zip' --exclude '*.gz' --exclude 'wp-config.php'
		
		tar -cf - . -P --exclude '*.zip' --exclude '*.gz' --exclude 'wp-config.php' | pv -s $(du -sb . | awk '{print $1}') | gzip > /var/www/$appname/primemover-$appname-migration-file.gz

		echo "Cleaning up..."
		rm database.sql
		rm table.prefix
		rm wp-config.last.config
		
		echo "Site $appname has been successfully packed up..."
		
		sitepack="/var/www/$appname/primemover-$appname-migration-file.gz"
		
	fi

}


# All of this is only going to work moving things into a GridPane server...
# Again, I'm working on it. 

ShipOnly() {
	
	cd $rootfolder
	if ! $(wp core is-installed --allow-root); 
	then
	  
		echo "This is not a valid WordPress install, skipping!!!"

	else
		
		echo "Packing up site $site_to_clone..."
		
		PackageSite
		
		echo "Migrating site $site_to_clone..."
		
		DoMigrate
		
	fi
	
	echo "Shipped $site_to_clone..."

}

SingleSite() {
	
	cd $rootfolder
	if ! $(wp core is-installed --allow-root); 
	then
	  
		echo "This is not a valid WordPress install, skipping!!!"

	else
		
		MakeSiteonRemote
		ShipOnly
		
	fi
	
	echo "Next site..."
	
}

CoreSiteLoop() {
	
	while read -r appname site_to_clone username rootfolder count 
	do
	    
		echo "Building site $site_to_clone from $rootfolder on remote server $remote_IP..."
		
		dots=$(echo "$site_to_clone" | awk -F. '{ print NF - 1 }')
			
		if [[ $site_to_clone == "staging."* ]] && [[ $dots -ge 2 ]]
		then
			echo "This is a staging site..."
			ShipOnly
		elif [[ $site_to_clone == "canary."* ]] && [[ $dots -ge 2 ]]
		then
			echo "This is a UpdateSafely site, skipping..."
		else
			#echo "Doing $appname $site_to_clone $username $rootfolder..."
			SingleSite
		fi
		
		#echo "Getting next site..."
				
	done <"/var/tmp/primemover.domains.tmp2"
	
	echo "All sites processed!"
	
}

# Secure Copy current packaged site to new server and restore
# All of this is only going to work moving things into a GridPane server...
# Again, I'm working on it. 

DoMigrate() {
	
	if [ "$y" = "1" ]
	then
		echo "An error was detected during a previous function, skipping the migration step for this site..."
		return 1
	fi
	
	echo "Waiting for remote site to completely provision..."
	
	while ssh -n root@$remote_IP [ ! -d /var/www/$site_to_clone/htdocs/wp-content/plugins/nginx-helper ]
	do
	  sleep 5
	done
	
	scp $sitepack root@$remote_IP:/var/www/$site_to_clone/GPBUP-$site_to_clone-CLONE.gz
	
	if [[ $y -gt 0 ]]
	then
		echo "The secure copy to the remote server failed for site $site_to_clone! Exiting..."
		return 1
	else
		echo "Successfully copied site pack for $site_to_clone to remote system $remote_IP"
		rm $sitepack
	fi
	
	ssh -n root@$remote_IP "sleep 1 && cd /var/www/$site_to_clone/htdocs && gprestore" < /dev/null
	
	echo "Site $site_to_clone restored on remote system $remote_IP"

	echo "Cleaning up..."
	
	sleep 1

}

WhatPlatform() {
	
	if [ -d /opt/gridpane ]
	then
		echo "This is a GridPane provisioned server..."
		envir="GP"
		gpDomains
	elif [ -d "/etc/nginx-sp" ]
	then
		echo "This is a ServerPilot managed VPS..."
		envir="SP"
		spDomains
	elif [ -d "/etc/nginx-rc/" ]
	then
		echo "This is a RunCloud managed VPS..."
		envir="RC"
		rcDomains
	elif [ -f "/usr/local/cpanel/cpanel" ]
	then
		echo "This is a CPanel managed VPS..."
		echo "CPANEL MIGRATIONS ARE HIGHLY EXPERIMENTAL!!!"
		ECHO " YOU'VE BEEN WARNED, HOMESLICE"
		envir="CP"
		cpDomains
	elif [ -f "/usr/local/bin/ee" ]
	then
		echo "This is a EasyEngine install... "
		envir="EE"
		gpDomains

	else
		echo "We don't yet have support for Plesk/CPanel or similar shared hosting environments."
		echo "Sorry. Deuces."
		exit 187;
	fi	

}

LoopLocalSites() {
	
	if [ $envir == "GP" ]
	then
		echo ""
		echo "Processing local GridPane Sites..."
		CoreSiteLoop
		
	elif [ $envir == "EE" ]
	then
		echo ""
		echo "Processing local EasyEngine Sites..."
		CoreSiteLoop
		
	elif [ $envir == "CP" ]
	then
		echo ""
		echo "Processing local CPanel Sites... even though we probably shouldn't."
		CoreSiteLoop
		
	elif [ $envir == "SP" ]
	then
		echo ""
		echo "Processing local ServerPilot Sites..."
		CoreSiteLoop
		
	elif [ $envir == "RC" ]
	then
		echo ""
		echo "Processing local RunCloud Sites..."
		CoreSiteLoop
	fi		

}

DoWork() {
	
	# Do Work Son...

	WhatPlatform # Now we where we're coming from and we SHOULD know all the domains as well...

	if [ "$site_to_clone" == "ALL" ] || [ "$site_to_clone" == "all" ]
	then 		
		echo ""
		echo "Determining this server's control environment..."
		LoopLocalSites

	else
		thedomain=$1 # The domain in question...
		domaindetails=$(sed -n "/$thedomain/p" /var/tmp/primemover.domains.tmp2 | head -1) # Find the first instance of that domain name (avoid staging etc)...
	
		echo $domaindetails | while read -r appname site_to_clone username rootfolder count 
		do
			if [ $envir == "GP" ]
			then
				echo ""
				echo "Processing single GridPane Site..."
				SingleSite
		
			elif [ $envir == "EE" ]
			then
				echo ""
				echo "Processing single EasyEngine Site..."
				SingleSite
			
			elif [ $envir == "CP" ]
			then
				echo ""
				echo "Processing single CPanel Site..."
				SingleSite
		
			elif [ $envir == "SP" ]
			then
				echo ""
				echo "Processing single ServerPilot Site..."
				SingleSite
		
			elif [ $envir == "RC" ]
			then
				echo ""
				echo "Processing single RunCloud Site..."
				SingleSite
			fi
		
		done		

	fi

}

if [[ $1 == "restore" ]]
then
	tableprefix=$(cat table.prefix)
	sed -i "/$table_prefix =/c\\$tableprefix" wp-config.php
	echo "Prefixes Fixed"

	if [ -f database.sql ]
	then
		wp db import database.sql --allow-root
	elif [ -f database.gz ]
	then
		tar -xzf database.gz
		wp db import database.sql --allow-root
	else
		echo "Error! Database backup file missing!"
		exit 187;
	fi

	echo "Database Imported... We Think"
	
	if [ -f database.sql ]
	then
		rm database.sql
	elif [ -f database.gz ]
	then
		rm database.gz
	else
		echo "No DB file to remove!"
	fi

	rm table.prefix
	
	currdir=$PWD
	appname=$(basename $currdir)
	
	if [[ $appname == "public" ]]
	then
		cd ..
		currdir=$PWD
		appname=$(basename $currdir)
		cd ../..
		username=$PWD
		username=$(basename $username)
		
		chown -R $username:$username /srv/users/$username/apps/$appname/public/*
	else
		echo "This is not a restore..."
	fi
else
	ServerPilotShell
	SPtoSP
fi



# Copyright 2018 PrimeMover.io - K. Patrick Gallagher
