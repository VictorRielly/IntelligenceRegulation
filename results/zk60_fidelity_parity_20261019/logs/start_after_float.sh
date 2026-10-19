#!/bin/bash
# start_after_float.sh FLOAT_GLOB -- command...: wait until a float cache matching the glob exists, then exec
G=$1; shift 2
until compgen -G "$G" > /dev/null; do sleep 20; done
exec "$@"
