#!/bin/bash

# PrimeMover.io

# Universal WordPress Migration Assistant

# Copyright 2018 Gridpane.com - K. Patrick Gallagher

# Easily move WordPress sites between two different servers managed by GridPane, ServerPilot, RunCloud and Others...

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root, exiting!!!" 
   exit 1
fi

MeImCounting() {
	
	echo "This is all very VERY aplha right now. Use at your own risk."
	echo " "
	echo " "
	echo "This is basically a neutered version of the MigrateSafely migration tool we use internally at GridPane.com"
	echo " "
	echo " "
	echo "So all kinds of things might be completely broken. Please feel free to help out."
	echo " "
	echo " "
	echo "Best of luck! Drop me a line at patrick at gridpane dot com"
	echo " "
	echo " "
	echo "In order for this to work (for ServerPilot and RunCloud) you need to have already created SSH keys on both your source server and your destination server."
	echo "You need to have also already added these keys between your source and destination server."
	echo "This all automatically works and happens if you're using GridPane because we kick all of the asses."

}
MeImCounting

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
	# LOTS of work needs to be added in here to make this work seamlessly between SP and RC nodes, and between RC and RC, and between SP and SP, and... you get the point.
	# LOTS of work needs to be added in here to make this work seamlessly between SP and RC nodes, and between RC and RC, and between SP and SP, and... you get the point.
	# LOTS of work needs to be added in here to make this work seamlessly between SP and RC nodes, and between RC and RC, and between SP and SP, and... you get the point.
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

# Install WP-CLI - Makes everything so much easier!!!
CheckWPcli() {
	
	if [ -f /usr/local/bin ]
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

# Check is SSH key present, if not make it so...
# This currently only applies to migrating IN to GridPane servers... 
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

		#tar -czf /home/$username/webapps/GPBUP-$appname-CLONE.gz . --exclude '*.zip' --exclude '*.gz' --exclude 'wp-config.php'
		
		tar -cf - . -P --exclude '*.zip' --exclude '*.gz' --exclude 'wp-config.php' | pv -s $(du -sb . | awk '{print $1}') | gzip > /home/$username/webapps/GPBUP-$appname-CLONE.gz

		echo "Cleaning up..."
		rm database.sql
		rm table.prefix
		rm wp-config.last.config
		
		echo "Site $site_to_clone has been successfully packed up..."
		
		sitepack="/home/$username/webapps/GPBUP-$appname-CLONE.gz"

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

		#tar -czf /srv/users/$username/apps/$appname/GPBUP-$appname-CLONE.gz . --exclude '*.zip' --exclude '*.gz' --exclude 'wp-config.php'
		
		tar -cf - . -P --exclude '*.zip' --exclude '*.gz' --exclude 'wp-config.php' | pv -s $(du -sb . | awk '{print $1}') | gzip > /srv/users/$username/apps/$appname/GPBUP-$appname-CLONE.gz

		echo "Cleaning up..."
		rm database.sql
		rm table.prefix
		rm wp-config.last.config
		
		echo "Site $appname has been successfully packed up..."
		
		sitepack="/srv/users/$username/apps/$appname/GPBUP-$appname-CLONE.gz"
		
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

		#tar -czf /home/$username/public_html/GPBUP-$appname-CLONE.gz . --exclude '*.zip' --exclude '*.gz' --exclude 'wp-config.php'
		
		tar -cf - . -P --exclude '*.zip' --exclude '*.gz' --exclude 'wp-config.php' | pv -s $(du -sb . | awk '{print $1}') | gzip > /home/$username/public_html/GPBUP-$appname-CLONE.gz

		echo "Exported site pack..."
		
		echo "Cleaning up..."
		rm database.sql
		rm table.prefix
		rm wp-config.last.config
		
		echo "Site $appname has been successfully packed up..."
		
		sitepack="/home/$username/public_html/GPBUP-$appname-CLONE.gz"
		
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

		#tar -czf /var/www/$appname/GPBUP-$appname-CLONE.gz . --exclude '*.zip' --exclude '*.gz' --exclude 'wp-config.php'
		
		tar -cf - . -P --exclude '*.zip' --exclude '*.gz' --exclude 'wp-config.php' | pv -s $(du -sb . | awk '{print $1}') | gzip > /var/www/$appname/GPBUP-$appname-CLONE.gz

		echo "Cleaning up..."
		rm database.sql
		rm table.prefix
		rm wp-config.last.config
		
		echo "Site $appname has been successfully packed up..."
		
		sitepack="/var/www/$appname/GPBUP-$appname-CLONE.gz"
		
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
				
	done < /var/tmp/primemover.domains.tmp2 
	
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

# Copyright 2017, 2018 PrimeMover.io - K. Patrick Gallagher
