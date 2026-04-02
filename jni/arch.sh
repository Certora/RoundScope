#!/bin/bash

pushd $JAVA_HOME/include >> /dev/null
echo $(find * -type d)
