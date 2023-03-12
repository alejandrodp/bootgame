#!/bin/sh

echo $((($(stat -c %s tarea.bin) + 511) / 512))
