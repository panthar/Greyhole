#!/bin/bash

# Copyright 2011 Guillaume Boudreau
# 
# This file is part of Greyhole.
# 
# Greyhole is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# Greyhole is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with Greyhole.  If not, see <http://www.gnu.org/licenses/>.


##########
# Synopsys
# This script is used to build new Greyhole versions. It will:
#   1. Create a source TGZ, and RPM & DEB packages
#   2. Upload the new files on the greyhole.net host
#   3. Update the APT & YUM repositories
#   4. Install the new version locally (using apt-get or yum, depending on what's available)
#   5. Upload the new files to GitHub
#   6. Update the CHANGELOG on http://www.greyhole.net/releases/CHANGELOG
#   7. Send 'New version available' notifications by email, Twitter (@GreyholeApp), Facebook (Greyhole) and IRC (#greyhole on Freenode).


#######
# Setup
#   sudo easy_install twitter
#   curl -O https://raw.github.com/dtompkins/fbcmd/master/fbcmd_update.php; sudo php fbcmd_update.php install && rm fbcmd_update.php && fbcmd
#   echo -n 'github_username:github_password' > .github_userpwd
#   echo -n 'nickserv_password' > .irc_password


#######
# Usage

if [ $# != 1 ]; then
	echo "Usage: $0 <version>"
	exit 1
fi


########
# Config

# Host that will be used for SSH/SCP; specify needed port/user/etc. in your .ssh/config
HOST='ssh.greyhole.net'

# Path, on $HOST, to upload packages to; can be relative to user's home.
PATH_TO_RELEASES='www/greyhole.net/releases'

# Path, on $HOST, that contain the scripts to be used to update the APT/YUM repositories; can be relative to user's home.
PATH_TO_REPOS_UPDATER='www/greyhole.net'

# URL of the CHANGELOG file; URL should point to $HOST:$PATH_TO_RELEASES/CHANGELOG
CHANGELOG_URL='http://www.greyhole.net/releases/CHANGELOG'

# Email address that will receive a new version notification, including the CHANGELOG
ANNOUNCE_EMAIL='releases-announce@greyhole.net'

# End of Config
###############


export VERSION=$1

# Clean unwanted files
find . -name "._*" -delete
find . -name ".DS_Store" -delete
find . -name ".AppleDouble" -delete


################
# Build packages

# RPM
archs='i386 armv5tel x86_64'
for arch in $archs; do
	export ARCH=$arch
	make rpm
	make amahi-rpm
done

# DEB
archs='i386 amd64'
for arch in $archs; do
	export ARCH=$arch
	make deb
done
               

#########################################
# Transfer files to HOST:PATH_TO_RELEASES

scp release/greyhole*$VERSION.tar.gz ${HOST}:${PATH_TO_RELEASES}/.
scp release/*greyhole-$VERSION-*.src.rpm ${HOST}:${PATH_TO_RELEASES}/rpm/src/.
scp release/*greyhole-$VERSION-*.x86_64.rpm ${HOST}:${PATH_TO_RELEASES}/rpm/x86_64/.
scp release/*greyhole-$VERSION-*.i386.rpm ${HOST}:${PATH_TO_RELEASES}/rpm/i386/.
scp release/*greyhole-$VERSION-*.armv5tel.rpm ${HOST}:${PATH_TO_RELEASES}/rpm/armv5tel/.
scp release/greyhole-$VERSION-*.deb ${HOST}:${PATH_TO_RELEASES}/deb/.


##########################
# Update YUM/APT repo data

ssh ${HOST} ${PATH_TO_REPOS_UPDATER}/update_yum_repodata.sh
ssh ${HOST} ${PATH_TO_REPOS_UPDATER}/update_deb_repodata.sh $VERSION


############################################################
# Update local greyhole package to latest, from YUM/APT repo

if [ -x /usr/bin/yum ]; then
	sudo yum update greyhole
	sudo rm /usr/bin/greyhole /usr/bin/greyhole-dfree
	sudo ln -s ~/greyhole/greyhole /usr/bin/greyhole
	sudo ln -s ~/greyhole/greyhole-dfree /usr/bin/greyhole-dfree
	sudo service greyhole condrestart
elif [ -x /usr/bin/apt-get ]; then
	sudo apt-get update && sudo apt-get install greyhole
	sudo rm /usr/bin/greyhole /usr/bin/greyhole-dfree
	sudo ln -s ~/greyhole/greyhole /usr/bin/greyhole
	sudo ln -s ~/greyhole/greyhole-dfree /usr/bin/greyhole-dfree
	sudo restart greyhole
fi


############################
# Upload new files to GitHub

./github-auto-post-downloads.php $VERSION


############################
# Update and email CHANGELOG

cd release
	LAST_TGZ=`ls -1atr *.tar.gz | grep -v web-app | grep -v 'hda-' | grep -B 1 greyhole-$VERSION | head -1`
	tar --wildcards -x "*/CHANGES" -f $LAST_TGZ
	tar --wildcards -x "*/CHANGES" -f greyhole-$VERSION.tar.gz

	diff -b */CHANGES | sed -e 's/^> /- /' | grep -v '^[0-9]*a[0-9]*\,[0-9]*$' > /tmp/gh_changelog

	find . -type d -name "greyhole-*" -exec rm -rf {} \; > /dev/null 2>&1
	find . -type d -name "hda-greyhole-*" -exec rm -rf {} \; > /dev/null 2>&1
	
	# Update $CHANGELOG_URL
	echo "What's new in $VERSION" > CHANGELOG
	echo "--------------------" >> CHANGELOG
	cat /tmp/gh_changelog >> CHANGELOG
	echo >> CHANGELOG
	curl -s "${CHANGELOG_URL}" >> CHANGELOG
	scp CHANGELOG ${HOST}:${PATH_TO_RELEASES}/CHANGELOG
cd ..


############################################
# Send notifications to Twitter/FB/IRC/email

/usr/local/bin/twitter set "New version available: $VERSION - ChangeLog: http://t.co/hZheYwg"
/usr/local/bin/fbcmd PPOST Greyhole "New version available: $VERSION - Downloads: http://www.greyhole.net/download/ or just use your package manager to update." 'ChangeLog' "${CHANGELOG_URL}"
./irc_notif.sh $VERSION

# Email
cat > /tmp/gh_email <<EOF
This is an automated email.

New RPM & DEB packages were created from a new Greyhole build: greyhole-$VERSION.tar.gz
You can find this new build at the usual http://www.greyhole.net/releases/
  and in the APT and YUM repositories.

Changes from the previous version are:
EOF
cat /tmp/gh_changelog >> /tmp/gh_email
mail -s "New Greyhole build available: $VERSION" $ANNOUNCE_EMAIL < /tmp/gh_email
