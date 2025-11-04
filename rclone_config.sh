#!/bin/bash

mkdir -p ~/.config/rclone
cp rclone.conf ~/.config/rclone/
chmod 600 ~/.config/rclone/rclone.conf

# Add rclone binary path to .bash_profile if not already there
if ! grep -q "export PATH=$(pwd)\\rclone:\$PATH" ~/.bash_profile 2>/dev/null; then
	echo "export PATH=$(pwd)/rclone:\$PATH" >> ~/.bash_profile
	echo "Added rclone to PATH in ~/.bash_profile"
	echo "Please source your bashrc."
fi


