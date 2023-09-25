#!/bin/bash

function main() {
    test_slight
    test_spin
    test_wws
    test_lunatic
    test_wasmtime
    test_wasmedge
    test_wasmer
}

function test_slight() {
    echo -e "\033[0;34mruntime:\033[1m slight\033[0m"

    docker run -d --interactive --quiet --name=wasm-shim-test \
        --platform=wasi/wasm32 \
        --runtime=io.containerd.slight.v1 \
        --publish=3000:3000 \
        ghcr.io/deislabs/containerd-wasm-shims/examples/slight-rust-hello:v0.9.0 / > /dev/null

    curl_check_eq 200 'hello world!' http://localhost:3000/hello
    curl_check_eq 204 '' http://localhost:3000/set -XPUT -d "some value"
    curl_check_eq 200 'some value' http://localhost:3000/get

    docker rm -f wasm-shim-test > /dev/null
}

function test_spin() {
    echo -e "\033[0;34mruntime:\033[1m spin\033[0m"

    docker run -d --interactive --quiet --name=wasm-shim-test \
        --platform=wasi/wasm32 \
        --runtime=io.containerd.spin.v1 \
        --publish=3000:80 \
        ghcr.io/deislabs/containerd-wasm-shims/examples/spin-rust-hello:v0.9.0 / > /dev/null

    curl_check_eq 200 'Hello world from Spin!' http://localhost:3000/hello

    docker rm -f wasm-shim-test > /dev/null
}

function test_wws() {
    echo -e "\033[0;34mruntime:\033[1m wws\033[0m"

    docker run -d --interactive --quiet --name=wasm-shim-test \
        --platform=wasi/wasm32 \
        --runtime=io.containerd.wws.v1 \
        --publish=3000:3000 \
        ghcr.io/deislabs/containerd-wasm-shims/examples/wws-js-hello:v0.9.0 / > /dev/null

    curl_check_regex 200 'Hello from Wasm Workers Server' http://localhost:3000/hello

    docker rm -f wasm-shim-test > /dev/null
}

function test_lunatic() {
    echo -e "\033[0;34mruntime:\033[1m lunatic\033[0m"

    docker run -d --interactive --quiet --name=wasm-shim-test \
        --platform=wasi/wasm32 \
        --runtime=io.containerd.lunatic.v1 \
        --publish=3000:3000 \
        ghcr.io/deislabs/containerd-wasm-shims/examples/lunatic-submillisecond:v0.9.0 / > /dev/null

    curl_check_eq 200 'Hello :)' http://localhost:3000/hello

    docker rm -f wasm-shim-test > /dev/null
}

function test_wasmtime() {
    echo -e "\033[0;34mruntime:\033[1m wasmtime\033[0m"

    docker run -d --interactive --quiet --name=wasm-shim-test \
        --platform=wasm32/wasi \
        --runtime=io.containerd.wasmtime.v1 \
        rumpl/hello-barcelona > /dev/null
    
    logs_check_regex 'Hola Barcelona!\nMy current OS is  wasm32'

    docker rm -f wasm-shim-test > /dev/null
}

function test_wasmedge() {
    echo -e "\033[0;34mruntime:\033[1m wasmedge\033[0m"

    docker run -d --interactive --quiet --name=wasm-shim-test \
        --platform=wasi/wasm \
        --runtime=io.containerd.wasmedge.v1 \
        --publish=3000:8080 \
        secondstate/rust-example-server > /dev/null
    
    curl_check_regex 200 'Try POSTing data' http://localhost:3000/
    curl_check_eq 200 'some data' http://localhost:3000/echo -XPOST -d "some data"

    docker rm -f wasm-shim-test > /dev/null
}

function test_wasmer() {
    echo -e "\033[0;34mruntime:\033[1m wasmer\033[0m"

    docker run -d --interactive --quiet --name=wasm-shim-test \
        --platform=wasm32/wasi \
        --runtime=io.containerd.wasmer.v1 \
        rumpl/hello-barcelona > /dev/null
    
    logs_check_regex 'Hola Barcelona!\nMy current OS is  wasm32'

    docker rm -f wasm-shim-test > /dev/null
}

######################

function curlf() {
    BODY_FILE=$(mktemp)
    CODE_FILE=$(mktemp)
    ERR_FILE=$(mktemp)
    curl --silent \
        --retry 5 \
        --retry-all-errors \
        --retry-delay 1 \
        --output $BODY_FILE \
        --write-out "%{http_code}" \
        "$@" > $CODE_FILE 2> $ERR_FILE
    SUCCESS="$?"
    CODE=$(cat $CODE_FILE)
    BODY=$(cat $BODY_FILE)
    ERR=$(cat $ERR_FILE)
    rm $BODY_FILE $CODE_FILE $ERR_FILE
    if [ "$SUCCESS" == "0" ]; then
        echo "$CODE"
        echo "$BODY"
    else
        echo "error"
        echo "$CODE"
        echo "$BODY"
        echo "$ERR"
    fi
}

function curl_check_eq() {
    EXPECTED_CODE=$1; shift
    EXPECTED_BODY=$1; shift
    URL=$1; shift
    OUTPUT=$(curlf "$URL" "$@")
    CODE=$(echo "$OUTPUT" | head -n 1)
    BODY=$(echo "$OUTPUT" | tail -n +2)
    if [ "$CODE" == "$EXPECTED_CODE" ] && [ "$BODY" == "$EXPECTED_BODY" ]; then
        echo -e "  \033[0;32m✓\033[0m ${URL}"
    else
        echo -e "  \033[0;31m✗\033[0m ${URL}"
        echo "    expected status code $EXPECTED_CODE, received $CODE"
        echo "    expected response \"$EXPECTED_BODY\", received \"$BODY\""
    fi
}

function curl_check_regex() {
    EXPECTED_CODE=$1; shift
    EXPECTED_BODY=$1; shift
    URL=$1; shift
    OUTPUT=$(curlf "$URL" "$@")
    CODE=$(echo "$OUTPUT" | head -n 1)
    BODY=$(echo "$OUTPUT" | tail -n +2)
    MATCHES=$(echo "$BODY" | grep -Plzq "$EXPECTED_BODY"; echo "$?")
    if [ "$CODE" == "$EXPECTED_CODE" ] && [ "$MATCHES" == "0" ]; then
        echo -e "  \033[0;32m✓\033[0m ${URL}"
    else
        echo -e "  \033[0;31m✗\033[0m ${URL}"
        echo "    expected status code $EXPECTED_CODE, received $CODE"
        echo "    expected response to match \"$EXPECTED_BODY\", received \"$BODY\""
    fi
}

function logs_check_regex() {
    EXPECTED_MSG=$1; shift
    URL=$1; shift
    for I in seq 10; do
        MSG=$(docker logs wasm-shim-test)
        MATCHES=$(echo "$MSG" | grep -Plzq "$EXPECTED_MSG"; echo "$?")
        if [ "$MATCHES" == "0" ]; then
            break;
        fi
        sleep 1
    done
    if [ "$MATCHES" == "0" ]; then
        echo -e "  \033[0;32m✓\033[0m logs"
    else
        echo -e "  \033[0;31m✗\033[0m logs"
        echo "    expected logs to match \"$EXPECTED_MSG\", actual logs \"$MSG\""
    fi
}

main