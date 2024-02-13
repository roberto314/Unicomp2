#!/bin/bash

OLDDIR=$(pwd)
USERDIR=/home/olimex
#echo "Edit this script first!"
#------------ uncomment all below ----------------
#cd $USERDIR
#sudo apt update
#sudo apt upgrade
sudo apt install git mc picocom tmux build-essential libusb-dev libftdi-dev libgpiod-dev git cmake minicom fbterm fbset ncurses-term neofetch automake libtool python3 python3-venv python3-pip console-data

git clone https://github.com/roberto314/xc3sprog-libgpio
mkdir xc3sprog-libgpio/build
cd xc3sprog-libgpio/build
cmake .. -DUSE_WIRINGPI=OFF
make
cp xc3sprog ~/.local/bin/xc3sprog
cd $OLDDIR

git clone https://github.com/jimeh/tmuxifier.git ~/.tmuxifier
sudo chmod u+s /usr/bin/fbterm  # prevent error "can`t change kernel map"
python3 -m pip install --upgrade pip setuptools wheel
sudo pip3 install pyA20 configobj pyserial

