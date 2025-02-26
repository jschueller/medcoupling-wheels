#!/bin/sh
docker build docker/manylinux -t medcoupling/manylinux
docker run --rm -e MAKEFLAGS='-j8' -v `pwd`:/io medcoupling/manylinux /io/build-wheels-linux.sh 9.14.0 cp310
