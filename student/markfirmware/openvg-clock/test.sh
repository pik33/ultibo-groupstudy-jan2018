#!/bin/bash

# on raspbian, build the program and reboot to it

set -ex
~/ultibo/core/lazbuild *.lpi
sudo cp kernel7.img /boot/test-kernel7.img
sudo cp /boot/test-config.txt /boot/config.txt
sudo reboot
