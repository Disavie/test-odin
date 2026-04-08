#!/bin/bash
gcc -c test.c -o test.o
ar rcs lib/test.a test.o
