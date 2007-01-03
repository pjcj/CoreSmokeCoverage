#! /bin/bash
# $Id$

cd ~abeltje/Test-Smoke/gcov
rm -f nohup.out
nohup ./buildgcov.sh $* &

