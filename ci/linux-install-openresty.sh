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
sudo apt-get install -y libldap2-dev openresty-pcre openresty-zlib

COMPILE_OPENSSL3=${COMPILE_OPENSSL3-no}
USE_OPENSSL3=${USE_OPENSSL3-no}
SSL_LIB_VERSION=${SSL_LIB_VERSION-openssl}

install_openssl_3(){
    # required for openssl 3.x config
    cpanm IPC/Cmd.pm
    wget --no-check-certificate https://www.openssl.org/source/openssl-3.1.3.tar.gz
    tar xvf openssl-*.tar.gz
    cd openssl-3.1.3
    OPENSSL3_PREFIX=$(pwd)
    ./config
    make -j $(nproc)
    make install
    export LD_LIBRARY_PATH=/usr/local/lib:/usr/local/lib64
    ldconfig
    export openssl_prefix="$OPENSSL3_PREFIX"
    cd ..
}

install_openssl_3
if [ "$OPENRESTY_VERSION" == "source" ]; then
    export zlib_prefix=/usr/local/openresty/zlib
    export pcre_prefix=/usr/local/openresty/pcre
    apt install -y build-essential
    export cc_opt="-DNGX_LUA_ABORT_AT_PANIC -I${zlib_prefix}/include -I${pcre_prefix}/include -I${openssl_prefix}/include"
    export ld_opt="-L${zlib_prefix}/lib -L${pcre_prefix}/lib -L${openssl_prefix}/lib -Wl,-rpath,${zlib_prefix}/lib:${pcre_prefix}/lib:${openssl_prefix}/lib"
    if [ "$COMPILE_OPENSSL3" == "yes" ]; then
        $openssl_prefix/bin/openssl fipsinstall -out $openssl_prefix/ssl/fipsmodule.cnf -module $openssl_prefix/lib/ossl-modules/fips.so
        sed -i 's@# .include fipsmodule.cnf@.include $openssl_prefix/ssl/fipsmodule.cnf@g; s/# \(fips = fips_sect\)/\1\nbase = base_sect\n\n[base_sect]\nactivate=1\n/g' $openssl_prefix/ssl/openssl.cnf
    fi
    ldconfig


    if [ "$SSL_LIB_VERSION" == "tongsuo" ]; then
        export openssl_prefix=/usr/local/tongsuo
        export zlib_prefix=$OPENRESTY_PREFIX/zlib
        export pcre_prefix=$OPENRESTY_PREFIX/pcre

        export cc_opt="-DNGX_LUA_ABORT_AT_PANIC -I${zlib_prefix}/include -I${pcre_prefix}/include -I${openssl_prefix}/include"
        export ld_opt="-L${zlib_prefix}/lib -L${pcre_prefix}/lib -L${openssl_prefix}/lib64 -Wl,-rpath,${zlib_prefix}/lib:${pcre_prefix}/lib:${openssl_prefix}/lib64"
    fi
    wget -q https://raw.githubusercontent.com/api7/apisix-build-tools/openssl3/build-apisix-base.sh
    chmod +x build-apisix-base.sh
    ./build-apisix-base.sh latest

    sudo apt-get install -y libldap2-dev openresty-pcre openresty-zlib

    exit 0
fi

export cc_opt="-DNGX_LUA_ABORT_AT_PANIC -I${openssl_prefix}/include"
export ld_opt="-L${openssl_prefix}/lib -Wl,-rpath,${openssl_prefix}/lib"

wget "https://raw.githubusercontent.com/api7/apisix-build-tools/openssl3/build-apisix-runtime.sh"
chmod +x build-apisix-runtime.sh
./build-apisix-runtime.sh latest
