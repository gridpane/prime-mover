# Prime Mover (PrimeMover.io) 

# CAUTION!!!

This is all VERY alpha right now. This isn't anything inherently "destructive" about this script other than the fact that it can theoretically fill your hard drive up in the process of making tar/gz clones of all of your sites. 

*Use at your own risk!*

# Description: 

PrimeMover.sh is a bash script that facilitates migration of WordPress sites into and out of servers managed by GridPane.com, ServerPilot, RunCloud, and some CPanel installations (currently only out of CPanel). 

This is a somewhat neutered version of the MigrateSafely migration tool we use internally at GridPane.com to migrate sites into our clients servers. 

Currently the following migrations are tested and working:

ServerPilot -> GridPane servers *WORKS*

RunCloud -> GridPane servers *WORKS*

EasyEngine/Webinoly -> GridPane servers *WORKS*

Some "Stock" Cpanel -> GridPane servers *WORKS*

ServerPilot -> ServerPilot *WORKS*

ServerPilot -> RunCloud *WORKS* (Sites must be manually built in RunCloud FIRST)

RunCloud -> ServerPilot *WORKS* (Single User - i.e. "runcloud" to "serverpilot")

All other migration "combinations" not explicitly listed above (i.e. RunCloud -> RunCloud) are NOT yet implemented or testing fails. 

Currently you need to have root access to both the source server and the destination. With all server types *other than GridPane* this works best if you've already generated a SSH key pair on both sides and have exchanged those keys and successfully tested a root login from the source to the destination. 

At the very least you'll need the root password for the destination server and root logins need to be allowed. 

Best of luck! Drop me a line at patrick at gridpane dot com

# INSTALL

More documentation on this will be forthcoming. 

But basically: 

1.) Download primemover.sh

2.) Run "chmod +x primemover.sh"

3.) Run "mv primemover.sh /usr/local/bin/primemover"

4.) Run "primemover" and the script will automatically detect what the source machine is and guide you through the migration process. 

# Notes

As this was built from our internal tools it obviously works best for migrating things into GridPane. In order to migrate into GridPane servers all you'll need your account API key which is accessible inside your account dashboard. SSH key exchange is handled automatically.

I'm not planning to build a version of this that doesn't explicitly use SSH keys. Knock yourself out.

I am also not planning on building a version of this which allows migration into CPanel/Plesk/similar. It's complicated enough getting sites OUT of CPanel and given that they don't have API site builds it's even more complicated to try to get sites to migrate in. This could be built obviously but you'd always need to manually build the sites at the destination. 

I will eventually build in the necessary mechanisms to migrate sites out of GridPane and into these other control panels but this is not a priority at this moment as I've yet to have anyone request this. All of the code required to do so is actually already there, if you know what you're looking for. 

Building sites on RunCloud currently can't be automated. You'll need to manually build them first. Their API is supposed to be coming by the end of February 2018 and we'll obviously circle back on this. Given the multi-step nature of manually building WordPress sites in RunCloud we will likely not work on additional RunCloud migration paths (i.e. RunCloud -> RunCloud) until their API is complete. 

This ONLY Migrates WordPress sites and NOTHING else. 

Please test and let me know if you hit any snags. 

Copyright 2018 - K. Patrick Gallagher

<p align="center"><strong>Sponsored by <a href="https://gridpane.com">GridPane.com</a></p><br>
<p align="center"><a href="https://gridpane.com"><img class="aligncenter" src="https://gridpane.com/wp-content/uploads/2018/02/gridpane-logo-spartan-300x57.png" alt="" width="300" height="57" /></a></p>
