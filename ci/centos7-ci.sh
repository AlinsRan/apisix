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

. ./ci/common.sh

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
    export LD_LIBRARY_PATH=$OPENSSL3_PREFIX${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
    ldconfig
    export openssl_prefix="$OPENSSL3_PREFIX"
    cd ..
}

install_dependencies() {
    export_version_info
    export_or_prefix

    # install build & runtime deps
    yum install -y wget tar gcc automake autoconf libtool make unzip \
        git sudo openldap-devel which ca-certificates openssl-devel \
        epel-release cpanminus

    # install newer curl
    yum makecache
    yum install -y libnghttp2-devel
    install_curl

    yum -y install centos-release-scl
    yum -y install devtoolset-9 patch wget git make sudo
    set +eu
    source scl_source enable devtoolset-9
    set -eu

    # install openresty to make apisix's rpm test work
    yum install -y yum-utils && yum-config-manager --add-repo https://openresty.org/package/centos/openresty.repo
    install_openssl_3
    wget "https://raw.githubusercontent.com/api7/apisix-build-tools/openssl3/build-apisix-runtime-debug-centos7.sh"
    wget "https://raw.githubusercontent.com/api7/apisix-build-tools/openssl3/build-apisix-runtime.sh"
    chmod +x build-apisix-runtime-debug-centos7.sh
    chmod +x build-apisix-runtime.sh
    ./build-apisix-runtime-debug-centos7.sh

    # install luarocks
    echo "THIS IS OPENSSL PREFIX $openssl_prefix"
    openssl_prefix=$openssl_prefix ./utils/linux-install-luarocks.sh

    # install etcdctl
    ./ci/linux-install-etcd-client.sh

    # install vault cli capabilities
    install_vault_cli

    # install test::nginx
    yum install -y cpanminus perl
    cpanm --notest Test::Nginx IPC::Run > build.log 2>&1 || (cat build.log && exit 1)

    # add go1.15 binary to the path
    mkdir build-cache
    # centos-7 ci runs on a docker container with the centos image on top of ubuntu host. Go is required inside the container.
    pushd build-cache/
    wget -q https://golang.org/dl/go1.17.linux-amd64.tar.gz && tar -xf go1.17.linux-amd64.tar.gz
    export PATH=$PATH:$(pwd)/go/bin
    popd
    # install and start grpc_server_example
    pushd t/grpc_server_example

    CGO_ENABLED=0 go build
    popd

    start_grpc_server_example

    # installing grpcurl
    install_grpcurl

    # install nodejs
    install_nodejs

    # grpc-web server && client
    pushd t/plugin/grpc-web
    ./setup.sh
    # back to home directory
    popd

    # install dependencies
    git clone https://github.com/openresty/test-nginx.git test-nginx
    create_lua_deps
}

run_case() {
    export_or_prefix
    make init
    set_coredns
    # run test cases
    FLUSH_ETCD=1 prove --timer -Itest-nginx/lib -I./ -r ${TEST_FILE_SUB_DIR} | tee /tmp/test.result
    rerun_flaky_tests /tmp/test.result
}

case_opt=$1
case $case_opt in
    (install_dependencies)
        install_dependencies
        ;;
    (run_case)
        run_case
        ;;
esac
