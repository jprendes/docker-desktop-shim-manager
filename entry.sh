#!/bin/sh
SCRIPT=$(cat <<'EOF'
alias docker="/var/lib/wasm/docker -H unix:///run/desktop/docker.sock"
case "$1" in
    ls)
        for RUNTIME in /var/lib/wasm/runtimes/containerd-shim-*; do
            ID=$(basename "$RUNTIME" | sed -E 's/.*-([^.-]+)-([^.-]+)/io.containerd.\1.\2/')
            if [ "$ID" == "$(basename "$RUNTIME")" ]; then continue; fi
            echo $ID
        done
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
    help|*)
        echo 'Invalid option "$1".'
        echo 'Usage:'
        echo '  docker-desktop-shim-manager ls              List available shims'
        echo '  docker-desktop-shim-manager install IMAGE   Install shims from an OCI image'
        echo '  docker-desktop-shim-manager install -       Install shims from a tar file in stdin'
        echo '  docker-desktop-shim-manager uninstall SHIM  Uninstall a shim (as listed by "ls")'
        ;;
esac
rm /var/lib/wasm/docker
EOF
)

# Get the latest shim digest
curl -sSfL "https://hub.docker.com/v2/namespaces/rumpl/repositories/containerd-wasi-shims/tags?page_size=1&ordering=last_updated" | jq -r '.results[0].digest' > /latest-shims

# Copy over requires files
/nsenter1 /usr/bin/tee /var/lib/wasm/latest-shims < /latest-shims > /dev/null
/nsenter1 /usr/bin/tee /var/lib/wasm/manager.sh < /manager.sh > /dev/null
/nsenter1 /usr/bin/tee /var/lib/wasm/docker < /docker > /dev/null
/nsenter1 /bin/chmod a+x /var/lib/wasm/docker /var/lib/wasm/manager.sh

# Run the main script
/nsenter1 /bin/sh /var/lib/wasm/manager.sh "$@"

# Cleanup
/nsenter1 /bin/rm /var/lib/wasm/docker /var/lib/wasm/manager.sh /var/lib/wasm/latest-shims