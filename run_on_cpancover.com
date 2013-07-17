#!/bin/sh

sh -v ./buildgcov.sh -noarchive
db=~/Test-Smoke/perl-current-gcov/cover_db
echo $db
find $db -type f -exec gzip -9 {} \;
chmod -R o=g $db
www=/usr/share/nginx/www/blead
new=$www/`date +%F`
sudo mv $new $new.$$
sudo mv $db $new
sudo rm $www/latest
sudo ln -s $new $www/latest
