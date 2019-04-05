#!/bin/sh

#check user that launch the script
#check that git is installed. 

#get custom theme
git clone https://github.com/arjmacedo/grub_theme_hidpi.git /tmp/install/grub-theme

#Copy the theme folder into grub themes (created if doesn't exist)
mkdir -p /boot/grub/themes && cp -r /tmp/install/grub-theme/SD_custom /boot/grub/themes/

#remove github local repo
rm -rf /tmp/install/grub-theme

#add theme into grub conf
sed -i '/^GRUB_THEME=/{h;s/=.*/=\/boot\/grub\/themes\/SD_custom\/theme.txt/};${x;/^$/{s//GRUB_THEME=\/boot\/grub\/themes\/SD_custom\/theme.txt/;H};x}' /etc/default/grub

#reload grub
update-grub2
