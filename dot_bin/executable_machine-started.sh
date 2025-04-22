#!/bin/bash

########################
#  machine-started.sh  #
#  by Meow       2025  #
########################
# Script to notify the ntfy server that the current machine has started.

source ../.profile

ntfy publish "Machine Booted"
