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
use t::APISIX 'no_plan';

repeat_each(1);
log_level('debug');
no_root_location();
no_shuffle();

add_block_preprocessor(sub {
    my ($block) = @_;

    my $yaml_config = $block->yaml_config // <<_EOC_;
apisix:
    node_listen: 1984
deployment:
    role: data_plane
    role_data_plane:
        config_provider: yaml
_EOC_

    $block->set_value("yaml_config", $yaml_config);

    my $routes = <<_EOC_;
routes:
  -
    uri: /hello
    upstream:
        nodes:
            "127.0.0.1:1980": 1
        type: roundrobin
#END
_EOC_

    $block->set_value("apisix_yaml", $block->apisix_yaml . $routes);

    if (!$block->request) {
        $block->set_value("request", "GET /t");
    }

    if (!$block->no_error_log && !$block->error_log) {
        $block->set_value("no_error_log", "[error]\n[alert]");
    }

    if ($block->sslhandshake) {
        my $sslhandshake = $block->sslhandshake;

        $block->set_value("config", <<_EOC_)
listen unix:\$TEST_NGINX_HTML_DIR/nginx.sock ssl;

location /t {
    content_by_lua_block {
        -- sync
        ngx.sleep(0.2)

        do
            local sock = ngx.socket.tcp()

            sock:settimeout(2000)

            local ok, err = sock:connect("unix:\$TEST_NGINX_HTML_DIR/nginx.sock")
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end

            $sslhandshake
            local req = "GET /hello HTTP/1.0\\r\\nHost: test.com\\r\\nConnection: close\\r\\n\\r\\n"
            local bytes, err = sock:send(req)
            if not bytes then
                ngx.say("failed to send http request: ", err)
                return
            end

            local line, err = sock:receive()
            if not line then
                ngx.say("failed to receive: ", err)
                return
            end

            ngx.say("received: ", line)

            local ok, err = sock:close()
            ngx.say("close: ", ok, " ", err)
        end  -- do
        -- collectgarbage()
    }
}
_EOC_
    }
});

run_tests();

__DATA__

=== TEST 1: sanity
--- apisix_yaml
ssls:
    -
        cert: |
            -----BEGIN CERTIFICATE-----
            MIICrTCCAZUCFGMzufO08QEC5gWneDy1yKjEJdVdMA0GCSqGSIb3DQEBCwUAMBEx
            DzANBgNVBAMMBlJPT1RDQTAgFw0yMzExMDkxMDM2MzdaGA8yMTIzMTAxNjEwMzYz
            N1owEzERMA8GA1UEAwwIdGVzdC5jb20wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAw
            ggEKAoIBAQC6uI2YmnIsPLyiMemnmjGFst3vTicocLJQDN4uhsbjATschHEGfU5S
            S/LegpGiXweBdcK9o0gYIJ5gVoT2ZUdBlOKiwCKYw1qv0XIqWCVaOfscMtsi2PNu
            o3EGlLePZxsVvGfz3dwjWEa9GL40sBfxGEXGo/r2mN0zII+YDlw2XvCrIv2s5O/E
            nzPEW8s2syaz5zc/h9X1vyzqqftfDKRaTEj+19WC4+kFFKTvHj8u0Z/ARejnI69N
            wz+8ZsSEb7MJdCZW4XNL1N57OzXBuifPPbbWAPVLuvqGDwnrRnAKdurHvkSuSoEi
            SA31WJEav9ajNEMZisjSWu7pkoQDQtNnAgMBAAEwDQYJKoZIhvcNAQELBQADggEB
            ABv+5q0y8rbsxg3BqqYqhGfF5N5xF1+SOENJblD4x7dUBrUB16g7gilq8gUTMrgF
            aBoVvp8fJKwE464NSGOkNbz/V5x4pZ4GlrgfuZCnw5qANnKQ8iXkUpq0L4eEhkln
            GWiDbDxHdxfa8FkgNbBFGTxfF/BdwFrB0TslsF/CMC2PqMtT2gbvNYebcO7+jvC+
            3QW5LBPCMsUA/rNqj3Z7PZOE/JlN/+a01h6tO3IqYiZLbw4zTuUMymuHMgedRwo1
            Lvw9N+22cTc4cX7RYG49yp8T0z2/mJm/oMCUN9zzCJ4Gc3GtcfO9A6uNP4p+JvfO
            LHjq42rRrPtw5Pr+Iy/a9wg=
            -----END CERTIFICATE-----
        key: |
            -----BEGIN PRIVATE KEY-----
            MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQC6uI2YmnIsPLyi
            MemnmjGFst3vTicocLJQDN4uhsbjATschHEGfU5SS/LegpGiXweBdcK9o0gYIJ5g
            VoT2ZUdBlOKiwCKYw1qv0XIqWCVaOfscMtsi2PNuo3EGlLePZxsVvGfz3dwjWEa9
            GL40sBfxGEXGo/r2mN0zII+YDlw2XvCrIv2s5O/EnzPEW8s2syaz5zc/h9X1vyzq
            qftfDKRaTEj+19WC4+kFFKTvHj8u0Z/ARejnI69Nwz+8ZsSEb7MJdCZW4XNL1N57
            OzXBuifPPbbWAPVLuvqGDwnrRnAKdurHvkSuSoEiSA31WJEav9ajNEMZisjSWu7p
            koQDQtNnAgMBAAECggEAESVVS0gTZ+CD6djvfcZ4+a/9FTZ1/g6rMRKdbGRP6xR3
            2xyGTHRBNulmeew/d0uGouqvYT6XJjAImwwW1ZFjQ7BqR0uhYam+sBppg13owCpG
            1sYMvVxyrhwwCsypNm/fWtWcLhaXWl+Gz2JwROJOsILsFVuFdhN/bGx3Ax1+djeF
            a8jf2kOIQseiXRfGcB23wecCwK1nAcKnpk1SCwR0QJ7UBSvB/MWOmBXiGXncIDyk
            mC3fXKnK2OPnrLmmM+bpg1wtjXqHJ5e9rlHrFz1aUZHR/GWapKIiMWkyjWxxJ1Gl
            KDwsoCcwkB5TOqdhOhsGBp1mjS1prFHhWM/CDVjR4QKBgQDlCEnMCrWVtKkT+Xaf
            nyBVq2Nwi70aURTftJLqpIEBb+GzF4XZDF2B12pACkbwz8aUwSWSXpcExv9TdzWs
            Lz860TWUDkZpRp1bugGK8uPCtvZpTpX9AWzQAGIR0lBBLqHTnoQLqarupJY6OV5y
            aVFPw4Dt2YkWmPbUPKv5Sw08SQKBgQDQtN9Vvklyzopzpgzr9VKsS7Ga/EWZZHIX
            D5fxqSsakypTCEFC+F+iaG8sAQDtH3UD0KdgYTG9C169tKw/qG7xGqZ/fveTwbY5
            ExZihwM/9igDVOYeZSgvpW+LV13eYo/m137t4VLi61KRPyQ9Fn5uTThuPQfJHx7z
            K3MjpJqyLwKBgQC/I6mi9ZURuVIZ72mGUWDE3mIAvT42RlCrWaH63QskzeCIfCsi
            NuWaxNJRW8JUmrJZ1s+qVfKm9ASF/cj3R/728T5Lr5Ynqd0NfjBna8mU6OjAfetC
            2Puco5U01lZP78DyQSpmKVUUEJunP9WImkhXzws8dP2ptELaYUAMrwv+sQKBgBSs
            liMMQoJY62YhYM5O8u2WYfWUX+CeDp8yMD8EHvz27w5ilvRnXjHcXobhYpIat6C1
            Hp9xgVfUtIHeT+HOcY74sN2YWjYMzlxBA8qmzS+c1sHdux3vr1do7+/Bq87HvLGF
            T1GJLIjF/tvcgV57x/JtO9XPveGyb4JvH2y8dYaJAoGBALAc6r0uDNjcCrncn+EI
            SiHeY/7iyUtbGd18XkJKiuwLekLFHrlyCsuErG9ihHL0MpaNVk88WwHeLGZTS6fc
            QufK3L+bxGPaXpDEEI/BFqFeX/JHX2FkrcsOQEk6eYs5MVwmwYTIFUvgL+OzKhsn
            norHMfddItsaYHgOc9jbgRhR
            -----END PRIVATE KEY-----
        snis:
            - "t.com"
            - "test.com"
--- sslhandshake
local sess, err = sock:sslhandshake(nil, "test.com", false)
if not sess then
    ngx.say("failed to do SSL handshake: ", err)
    return
end
--- response_body
received: HTTP/1.1 200 OK
close: 1 nil
--- error_log
server name: "test.com"



=== TEST 2: single sni
--- apisix_yaml
ssls:
    -
        cert: |
            -----BEGIN CERTIFICATE-----
            MIICrTCCAZUCFGMzufO08QEC5gWneDy1yKjEJdVdMA0GCSqGSIb3DQEBCwUAMBEx
            DzANBgNVBAMMBlJPT1RDQTAgFw0yMzExMDkxMDM2MzdaGA8yMTIzMTAxNjEwMzYz
            N1owEzERMA8GA1UEAwwIdGVzdC5jb20wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAw
            ggEKAoIBAQC6uI2YmnIsPLyiMemnmjGFst3vTicocLJQDN4uhsbjATschHEGfU5S
            S/LegpGiXweBdcK9o0gYIJ5gVoT2ZUdBlOKiwCKYw1qv0XIqWCVaOfscMtsi2PNu
            o3EGlLePZxsVvGfz3dwjWEa9GL40sBfxGEXGo/r2mN0zII+YDlw2XvCrIv2s5O/E
            nzPEW8s2syaz5zc/h9X1vyzqqftfDKRaTEj+19WC4+kFFKTvHj8u0Z/ARejnI69N
            wz+8ZsSEb7MJdCZW4XNL1N57OzXBuifPPbbWAPVLuvqGDwnrRnAKdurHvkSuSoEi
            SA31WJEav9ajNEMZisjSWu7pkoQDQtNnAgMBAAEwDQYJKoZIhvcNAQELBQADggEB
            ABv+5q0y8rbsxg3BqqYqhGfF5N5xF1+SOENJblD4x7dUBrUB16g7gilq8gUTMrgF
            aBoVvp8fJKwE464NSGOkNbz/V5x4pZ4GlrgfuZCnw5qANnKQ8iXkUpq0L4eEhkln
            GWiDbDxHdxfa8FkgNbBFGTxfF/BdwFrB0TslsF/CMC2PqMtT2gbvNYebcO7+jvC+
            3QW5LBPCMsUA/rNqj3Z7PZOE/JlN/+a01h6tO3IqYiZLbw4zTuUMymuHMgedRwo1
            Lvw9N+22cTc4cX7RYG49yp8T0z2/mJm/oMCUN9zzCJ4Gc3GtcfO9A6uNP4p+JvfO
            LHjq42rRrPtw5Pr+Iy/a9wg=
            -----END CERTIFICATE-----
        key: |
            -----BEGIN PRIVATE KEY-----
            MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQC6uI2YmnIsPLyi
            MemnmjGFst3vTicocLJQDN4uhsbjATschHEGfU5SS/LegpGiXweBdcK9o0gYIJ5g
            VoT2ZUdBlOKiwCKYw1qv0XIqWCVaOfscMtsi2PNuo3EGlLePZxsVvGfz3dwjWEa9
            GL40sBfxGEXGo/r2mN0zII+YDlw2XvCrIv2s5O/EnzPEW8s2syaz5zc/h9X1vyzq
            qftfDKRaTEj+19WC4+kFFKTvHj8u0Z/ARejnI69Nwz+8ZsSEb7MJdCZW4XNL1N57
            OzXBuifPPbbWAPVLuvqGDwnrRnAKdurHvkSuSoEiSA31WJEav9ajNEMZisjSWu7p
            koQDQtNnAgMBAAECggEAESVVS0gTZ+CD6djvfcZ4+a/9FTZ1/g6rMRKdbGRP6xR3
            2xyGTHRBNulmeew/d0uGouqvYT6XJjAImwwW1ZFjQ7BqR0uhYam+sBppg13owCpG
            1sYMvVxyrhwwCsypNm/fWtWcLhaXWl+Gz2JwROJOsILsFVuFdhN/bGx3Ax1+djeF
            a8jf2kOIQseiXRfGcB23wecCwK1nAcKnpk1SCwR0QJ7UBSvB/MWOmBXiGXncIDyk
            mC3fXKnK2OPnrLmmM+bpg1wtjXqHJ5e9rlHrFz1aUZHR/GWapKIiMWkyjWxxJ1Gl
            KDwsoCcwkB5TOqdhOhsGBp1mjS1prFHhWM/CDVjR4QKBgQDlCEnMCrWVtKkT+Xaf
            nyBVq2Nwi70aURTftJLqpIEBb+GzF4XZDF2B12pACkbwz8aUwSWSXpcExv9TdzWs
            Lz860TWUDkZpRp1bugGK8uPCtvZpTpX9AWzQAGIR0lBBLqHTnoQLqarupJY6OV5y
            aVFPw4Dt2YkWmPbUPKv5Sw08SQKBgQDQtN9Vvklyzopzpgzr9VKsS7Ga/EWZZHIX
            D5fxqSsakypTCEFC+F+iaG8sAQDtH3UD0KdgYTG9C169tKw/qG7xGqZ/fveTwbY5
            ExZihwM/9igDVOYeZSgvpW+LV13eYo/m137t4VLi61KRPyQ9Fn5uTThuPQfJHx7z
            K3MjpJqyLwKBgQC/I6mi9ZURuVIZ72mGUWDE3mIAvT42RlCrWaH63QskzeCIfCsi
            NuWaxNJRW8JUmrJZ1s+qVfKm9ASF/cj3R/728T5Lr5Ynqd0NfjBna8mU6OjAfetC
            2Puco5U01lZP78DyQSpmKVUUEJunP9WImkhXzws8dP2ptELaYUAMrwv+sQKBgBSs
            liMMQoJY62YhYM5O8u2WYfWUX+CeDp8yMD8EHvz27w5ilvRnXjHcXobhYpIat6C1
            Hp9xgVfUtIHeT+HOcY74sN2YWjYMzlxBA8qmzS+c1sHdux3vr1do7+/Bq87HvLGF
            T1GJLIjF/tvcgV57x/JtO9XPveGyb4JvH2y8dYaJAoGBALAc6r0uDNjcCrncn+EI
            SiHeY/7iyUtbGd18XkJKiuwLekLFHrlyCsuErG9ihHL0MpaNVk88WwHeLGZTS6fc
            QufK3L+bxGPaXpDEEI/BFqFeX/JHX2FkrcsOQEk6eYs5MVwmwYTIFUvgL+OzKhsn
            norHMfddItsaYHgOc9jbgRhR
            -----END PRIVATE KEY-----
        sni: "test.com"
--- sslhandshake
local sess, err = sock:sslhandshake(nil, "test.com", false)
if not sess then
    ngx.say("failed to do SSL handshake: ", err)
    return
end
--- response_body
received: HTTP/1.1 200 OK
close: 1 nil
--- error_log
server name: "test.com"



=== TEST 3: bad cert
--- apisix_yaml
ssls:
    -
        cert: |
            -----BEGIN CERTIFICATE-----
            MIIDrzCCApegAwIBAgIJAI3Meu/gJVTLMA0GCSqGSIb3DQEBCwUAMG4xCzAJBgNV
            BAYTAkNOMREwDwYDVQQIDAhaaGVqaWFuZzERMA8GA1UEBwwISGFuZ3pob3UxDTAL
            BgNVBAoMBHRlc3QxDTALBgNVBAsMBHRlc3QxGzAZBgNVBAMMEmV0Y2QuY2x1c3Rl
            ci5sb2NhbDAeFw0yMDEwMjgwMzMzMDJaFw0yMTEwMjgwMzMzMDJaMG4xCzAJBgNV
            BAYTAkNOMREwDwYDVQQIDAhaaGVqaWFuZzERMA8GA1UEBwwISGFuZ3pob3UxDTAL
            BgNVBAoMBHRlc3QxDTALBgNVBAsMBHRlc3QxGzAZBgNVBAMMEmV0Y2QuY2x1c3Rl
            ci5sb2NhbDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAJ/qwxCR7g5S
            s9+VleopkLi5pAszEkHYOBpwF/hDeRdxU0I0e1zZTdTlwwPy2vf8m3kwoq6fmNCt
            tdUUXh5Wvgi/2OA8HBBzaQFQL1Av9qWwyES5cx6p0ZBwIrcXQIsl1XfNSUpQNTSS
            D44TGduXUIdeshukPvMvLWLezynf2/WlgVh/haWtDG99r/Gj3uBdjl0m/xGvKvIv
            quDmvxteXWdlsz8o5kQT6a4DUtWhpPIfNj9oZfPRs3LhBFQ74N70kVxMOCdec1lU
            bnFzLIMGlz0CAwEAAaNQME4wHQYDVR0OBBYEFFHeljijrr+SPxlH5fjHRPcC7bv2
            MB8GA1UdIwQYMBaAFFHeljijrr+SPxlH5fjHRPcC7bv2MAwGA1UdEwQFMAMBAf8w
            DQYJKoZIhvcNAQELBQADggEBAG6NNTK7sl9nJxeewVuogCdMtkcdnx9onGtCOeiQ
            qvh5Xwn9akZtoLMVEdceU0ihO4wILlcom3OqHs9WOd6VbgW5a19Thh2toxKidHz5
            rAaBMyZsQbFb6+vFshZwoCtOLZI/eIZfUUMFqMXlEPrKru1nSddNdai2+zi5rEnM
            HCot43+3XYuqkvWlOjoi9cP+C4epFYrxpykVbcrtbd7TK+wZNiK3xtDPnVzjdNWL
            geAEl9xrrk0ss4nO/EreTQgS46gVU+tLC+b23m2dU7dcKZ7RDoiA9bdVc4a2IsaS
            2MvLL4NZ2nUh8hAEHiLtGMAV3C6xNbEyM07hEpDW6vk6tqk=
            -----END CERTIFICATE-----
        key: |
            -----BEGIN PRIVATE KEY-----
            MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQC6uI2YmnIsPLyi
            MemnmjGFst3vTicocLJQDN4uhsbjATschHEGfU5SS/LegpGiXweBdcK9o0gYIJ5g
            VoT2ZUdBlOKiwCKYw1qv0XIqWCVaOfscMtsi2PNuo3EGlLePZxsVvGfz3dwjWEa9
            GL40sBfxGEXGo/r2mN0zII+YDlw2XvCrIv2s5O/EnzPEW8s2syaz5zc/h9X1vyzq
            qftfDKRaTEj+19WC4+kFFKTvHj8u0Z/ARejnI69Nwz+8ZsSEb7MJdCZW4XNL1N57
            OzXBuifPPbbWAPVLuvqGDwnrRnAKdurHvkSuSoEiSA31WJEav9ajNEMZisjSWu7p
            koQDQtNnAgMBAAECggEAESVVS0gTZ+CD6djvfcZ4+a/9FTZ1/g6rMRKdbGRP6xR3
            2xyGTHRBNulmeew/d0uGouqvYT6XJjAImwwW1ZFjQ7BqR0uhYam+sBppg13owCpG
            1sYMvVxyrhwwCsypNm/fWtWcLhaXWl+Gz2JwROJOsILsFVuFdhN/bGx3Ax1+djeF
            a8jf2kOIQseiXRfGcB23wecCwK1nAcKnpk1SCwR0QJ7UBSvB/MWOmBXiGXncIDyk
            mC3fXKnK2OPnrLmmM+bpg1wtjXqHJ5e9rlHrFz1aUZHR/GWapKIiMWkyjWxxJ1Gl
            KDwsoCcwkB5TOqdhOhsGBp1mjS1prFHhWM/CDVjR4QKBgQDlCEnMCrWVtKkT+Xaf
            nyBVq2Nwi70aURTftJLqpIEBb+GzF4XZDF2B12pACkbwz8aUwSWSXpcExv9TdzWs
            Lz860TWUDkZpRp1bugGK8uPCtvZpTpX9AWzQAGIR0lBBLqHTnoQLqarupJY6OV5y
            aVFPw4Dt2YkWmPbUPKv5Sw08SQKBgQDQtN9Vvklyzopzpgzr9VKsS7Ga/EWZZHIX
            D5fxqSsakypTCEFC+F+iaG8sAQDtH3UD0KdgYTG9C169tKw/qG7xGqZ/fveTwbY5
            ExZihwM/9igDVOYeZSgvpW+LV13eYo/m137t4VLi61KRPyQ9Fn5uTThuPQfJHx7z
            K3MjpJqyLwKBgQC/I6mi9ZURuVIZ72mGUWDE3mIAvT42RlCrWaH63QskzeCIfCsi
            NuWaxNJRW8JUmrJZ1s+qVfKm9ASF/cj3R/728T5Lr5Ynqd0NfjBna8mU6OjAfetC
            2Puco5U01lZP78DyQSpmKVUUEJunP9WImkhXzws8dP2ptELaYUAMrwv+sQKBgBSs
            liMMQoJY62YhYM5O8u2WYfWUX+CeDp8yMD8EHvz27w5ilvRnXjHcXobhYpIat6C1
            Hp9xgVfUtIHeT+HOcY74sN2YWjYMzlxBA8qmzS+c1sHdux3vr1do7+/Bq87HvLGF
            T1GJLIjF/tvcgV57x/JtO9XPveGyb4JvH2y8dYaJAoGBALAc6r0uDNjcCrncn+EI
            SiHeY/7iyUtbGd18XkJKiuwLekLFHrlyCsuErG9ihHL0MpaNVk88WwHeLGZTS6fc
            QufK3L+bxGPaXpDEEI/BFqFeX/JHX2FkrcsOQEk6eYs5MVwmwYTIFUvgL+OzKhsn
            norHMfddItsaYHgOc9jbgRhR
            -----END PRIVATE KEY-----
        snis:
            - "t.com"
            - "test.com"
--- error_log
failed to parse cert
--- error_code: 404
