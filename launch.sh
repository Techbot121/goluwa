#!/bin/bash
ARCH=$(getconf LONG_BIT)

if [ $ARCH -eq "64" ]; then
	cd bin/linux/x64
else
	cd bin/linux/x86
fi

export LD_LIBRARY_PATH=.:$LD_LIBRARY_PATH

while true; do
	./luajit -e 'PLATFORM = "glw" dofile("../../../lua/init.lua")'
	if [ $? -eq 0 ]; then break; fi
	sleep 1
done
