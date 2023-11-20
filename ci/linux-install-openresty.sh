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
set -euo pipefail

source ./ci/common.sh

export_version_info

ARCH=${ARCH:-`(uname -m | tr '[:upper:]' '[:lower:]')`}
arch_path=""
if [[ $ARCH == "arm64" ]] || [[ $ARCH == "aarch64" ]]; then
    arch_path="arm64/"
fi

wget -qO - https://openresty.org/package/pubkey.gpg | sudo apt-key add -
wget -qO - http://repos.apiseven.com/pubkey.gpg | sudo apt-key add -
sudo apt-get -y update --fix-missing
sudo apt-get -y install software-properties-common
sudo add-apt-repository -y "deb https://openresty.org/package/${arch_path}ubuntu $(lsb_release -sc) main"
sudo add-apt-repository -y "deb http://repos.apiseven.com/packages/${arch_path}debian bullseye main"

sudo apt-get update
sudo apt-get install -y libldap2-dev openresty-pcre openresty-zlib lua5.1 liblua5.1 cpanminus openresty

COMPILE_FIPS=${COMPILE_FIPS-no}
SSL_LIB_VERSION=${SSL_LIB_VERSION-openssl}


if [ "$SSL_LIB_VERSION" == "tongsuo" ]; then
    export openssl_prefix=/usr/local/tongsuo
    export zlib_prefix=$OPENRESTY_PREFIX/zlib
    export pcre_prefix=$OPENRESTY_PREFIX/pcre

    export cc_opt="-DNGX_LUA_ABORT_AT_PANIC -I${zlib_prefix}/include -I${pcre_prefix}/include -I${openssl_prefix}/include"
    export ld_opt="-L${zlib_prefix}/lib -L${pcre_prefix}/lib -L${openssl_prefix}/lib -L${openssl_prefix}/lib64 -Wl,-rpath,${zlib_prefix}/lib:${pcre_prefix}/lib:${openssl_prefix}/lib:${openssl_prefix}/lib64"
    wget --no-check-certificate "https://raw.githubusercontent.com/api7/apisix-build-tools/master/build-apisix-runtime.sh"
    chmod +x build-apisix-runtime.sh
    ./build-apisix-runtime.sh latest
elif [ "$OPENRESTY_VERSION" == "source" ]; then
    if [ "$COMPILE_FIPS" == "yes" ]; then
        . ./utils/install-openssl-fips.sh
    else
        . ./utils/install-openssl.sh
    fi
    echo $openssl_prefix
    export zlib_prefix=/usr/local/openresty/zlib
    export pcre_prefix=/usr/local/openresty/pcre
    apt install -y build-essential
    export cc_opt="-DNGX_LUA_ABORT_AT_PANIC -I${zlib_prefix}/include -I${pcre_prefix}/include -I${openssl_prefix}/include"
    export ld_opt="-L${zlib_prefix}/lib -L${pcre_prefix}/lib -L${openssl_prefix}/lib -L${openssl_prefix}/lib64 -Wl,-rpath,${zlib_prefix}/lib:${pcre_prefix}/lib:${openssl_prefix}/lib:${openssl_prefix}/lib64"
    ldconfig

    wget --no-check-certificate "https://raw.githubusercontent.com/api7/apisix-build-tools/master/build-apisix-runtime.sh"
     chmod +x build-apisix-runtime.sh
    ./build-apisix-runtime.sh latest

    sudo apt-get install -y libldap2-dev openresty-pcre openresty-zlib
else
    . ./utils/install-openssl.sh
    export cc_opt="-DNGX_LUA_ABORT_AT_PANIC -I${openssl_prefix}/include"
    export ld_opt="-L${openssl_prefix}/lib -L${openssl_prefix}/lib64 -Wl,-rpath,${openssl_prefix}/lib:${openssl_prefix}/lib64"
    wget --no-check-certificate "https://raw.githubusercontent.com/api7/apisix-build-tools/master/build-apisix-runtime.sh"
    chmod +x build-apisix-runtime.sh
    ./build-apisix-runtime.sh latest
fi


