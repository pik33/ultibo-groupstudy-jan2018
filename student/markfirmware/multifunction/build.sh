#!/bin/bash
set -e # exit script on any error

LPI=multifunction.lpi

if [[ -e /c/Ultibo/Core ]]
then
    pushd /c/Ultibo/Core/ # for some reason at this time, need to run from this folder
    ./lazbuild.exe $(dirs -l +1)/$LPI
    popd
else
    export PATH=$HOME/ultibo/core:$PATH
    lazbuild $LPI
fi
