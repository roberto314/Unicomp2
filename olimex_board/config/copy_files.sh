#!/bin/bash

#OLDDIR=$(pwd)
#USERDIR=/home/olimex

cp .bashrc ~/
cp .profile ~/
cp .fbtermrc ~/
cp .tmux.conf ~/
cp .selected_editor ~/
sudo cp motd /etc
sudo cp profile /etc
sudo cp sudoers /etc
sudo chmod ug+r /etc/sudoers
sudo chown root:root /etc/sudoers
cp layouts/* ~/.tmuxifier/layouts/
cp mc/* ~/.config/mc/

#cd $OLDDIR
