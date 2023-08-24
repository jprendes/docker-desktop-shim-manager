alias docker="/var/lib/wasm/docker -H unix:///run/desktop/docker.sock"

case "$1" in
    ""|ls)
        RUNTIMES=$(find /var/lib/wasm/runtimes/ -name 'containerd-shim-*' -type f -executable -mindepth 1 -maxdepth 1 -exec echo {} \;)
        if [ "$RUNTIMES" == "" ]; then
            echo "No shims installed"
        else
            for RUNTIME in $RUNTIMES; do
                ID=$(basename "$RUNTIME" | sed -E 's/.*-([^.-]+)-([^.-]+)/io.containerd.\1.\2/')
                if [ "$ID" == "$(basename "$RUNTIME")" ]; then continue; fi
                echo $ID
            done
        fi
        ;;
    install)
        case "$2" in
            latest)
                IMAGE="rumpl/containerd-wasi-shims@$(cat /var/lib/wasm/latest-shims)"
                ID=$(docker create --quiet --entrypoint=/ "$IMAGE")
                docker export $ID | tar -C /var/lib/wasm/runtimes -xf -
                docker rm $ID > /dev/null
                ;;
            -)
                tar -C /var/lib/wasm/runtimes -xf -
                ;;
            *)
                ID=$(docker create --quiet --entrypoint=/ "$2")
                docker export $ID | tar -C /var/lib/wasm/runtimes -xf -
                docker rm $ID > /dev/null
                ;;
        esac
        ;;
    uninstall)
        NAME=$(echo "$2" | sed -E 's/.*\.([^.-]+)\.([^.-]+)/containerd-shim-\1-\2/')
        rm -f "/var/lib/wasm/runtimes/$NAME"
        ;;
    debug)
        case "$2" in
            ls)
                ls -alh "/var/lib/wasm/runtimes/$3"
                ;;
            rm)
                rm -rf "/var/lib/wasm/runtimes/$3"
                ;;
            rm-all)
                find /var/lib/wasm/runtimes/ -mindepth 1 -maxdepth 1 -exec rm -rf {} \;
                ;;
        esac
        ;;
    help)
        echo 'Usage:'
        echo '  dd-shim-mngr ls              List available shims'
        echo '  dd-shim-mngr install IMAGE   Install shims from an OCI image'
        echo '  dd-shim-mngr install -       Install shims from a tar file in stdin'
        echo '  dd-shim-mngr install latest  Install latest upstream shims'
        echo '  dd-shim-mngr uninstall SHIM  Uninstall a shim (as listed by "ls")'
        ;;
    *)
        echo 'Invalid option "'$1'".'
        /bin/sh /var/lib/wasm/manager.sh help
esac
