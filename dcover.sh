#! /bin/bash

# $Id$

GCOV_DEBUG=${GCOV_DEBUG:-""}

basedir="$HOME/Test-Smoke"
builddir="$basedir/perl-current-gcov"
coverdir=`ls "$builddir/ext" | grep Devel-Cover`
echo "Devel::Cover is at $coverdir"

incbase="$builddir/ext/$coverdir/blib"
usecover=-MDevel::Cover=-ignore,\\.t$,-inc,/does/not/exist

cd $builddir/t
pwd

for argv ; do
    ./perl -I$builddir/lib -I$incbase/lib -I$incbase/arch $usecover \
           $GCOV_DEBUG $argv
done

