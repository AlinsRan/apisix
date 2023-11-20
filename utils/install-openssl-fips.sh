#!/usr/bin/env bash
#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
set -ex
# required for openssl 3.x config
if [ ! -d "$(pwd)/openssl-3.1.3" ]; then
    cpanm IPC/Cmd.pm
    wget --no-check-certificate https://www.openssl.org/source/openssl-3.1.3.tar.gz
    tar xvf openssl-*.tar.gz
    cd openssl-3.1.3
    OPENSSL3_PREFIX=$(pwd)
    ./config enable-fips --prefix=/usr/local/openssl --openssldir=/usr/local/openssl
    make -j $(nproc)
    sudo make install
    export LD_LIBRARY_PATH=$OPENSSL3_PREFIX${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
    sudo ldconfig
    export openssl_prefix="/usr/local/openssl"
    cd ..
fi

