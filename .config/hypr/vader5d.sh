#!/bin/bash
for d in /sys/bus/hid/devices/*37D7*; do
    [ -e "$d" ] || continue
    b=$(basename "$d")
    echo -n "$b" | sudo tee /sys/bus/hid/drivers/hid-generic/bind >/dev/null 2>&1
done
sleep 1
exec sudo /usr/local/bin/vader5d -c /home/florian/.config/vader5/config.toml
