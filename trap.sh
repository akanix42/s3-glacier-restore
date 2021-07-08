#!/usr/bin/env bash

trap 'trap - INT; kill -s HUP -- -$$' INT
