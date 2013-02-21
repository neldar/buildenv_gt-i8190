#! /bin/sh

gcc -c rsa.c
gcc -c sha.c
gcc rsa.o sha.o mkbootimg.c -w -o mkbootimg
rm -f *.o
