#!/bin/sh

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