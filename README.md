# docker-desktop-shim-manager

A container image to install and uninstall WebAssembly shims in Docker Desktop.

## Usage

```bash
alias dd-shim-mngr="docker run --rm --privileged --pid=host docker-desktop-shim-manager"
dd-shim-mngr help # show help
dd-shim-mngr ls # list all available wasm shims
dd-shim-mngr install latest # install latest upstream shims
```
