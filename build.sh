#!/bin/bash

git submodule update --init --recursive
cd DerelictImgui/cimgui/cimgui
make -j4
