#!/bin/bash

pkill -f "mix run"
git pull
nohup mix run --no-halt &
