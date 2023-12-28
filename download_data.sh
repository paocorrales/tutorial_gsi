#!/bin/sh

# The observations and backgroud files will be downloaded from a Zenodo record. 
# They can also be downloaded manually from https://zenodo.org/records/10439645

# OBS
wget -O OBS.tar.gz https://zenodo.org/records/10439645/files/OBS.tar.gz?download=1
tar -xvf OBS.tar.gz

# GUESS
wget -O GUESS.tar.gz https://zenodo.org/records/10439645/files/GUESS.tar.gz?download=1
tar -xvf GUESS.tar.gz
