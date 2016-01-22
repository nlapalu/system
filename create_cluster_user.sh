#!/usr/bin/env bash

userlogin=$1

# adduser
adduser $userlogin

# adduser to groupe vboxsf
usermod -a -G vboxsf $userlogin

# create repositories
mkdir /media/sf_ubucluster/save/$userlogin
mkdir /media/sf_ubucluster/work/$userlogin

# create links
ln -s /media/sf_ubucluster/save/$userlogin /home/$userlogin/save
ln -s /media/sf_ubucluster/work/$userlogin /home/$userlogin/work
