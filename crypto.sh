#!/bin/bash

set -eu
set -o pipefail

# Debug
export DEBUG="0"

# Filesystem locations
export PASSBOOK="passbook.txt"

# Binary locations
export GPG_BINARY="/usr/local/bin/gpg"
export READLINK="/usr/local/bin/greadlink"

# GPG options
export GPG_OPTS="--quiet --batch --yes --no-symkey-cache"
export GPG_ALGO="AES256"

# Verify the binaries we need, exist
if [ ! -x "${GPG_BINARY}" ]; then
    echo "ERROR: ${GPG_BINARY} is not present/executable"
    exit 1
fi
if [ ! -x "${READLINK}" ]; then
    echo "ERROR: ${READLINK} is not present/executable"
    exit 1
fi

# Verify the repo passphrase we need, exists
if [ "${REPO_GPG_PASSPHRASE}" == "" ]; then
    echo "ERROR: REPO_GPG_PASSPHRASE is unset"
    exit 1
fi

SCRIPT_NAME="$(basename "$0")"
SCRIPT_HOME="$(dirname "$("${READLINK}" -f "$0")")"

function gpg_wrapper() {
    # WARNING: DO NOT LEAVE THIS DBG ENABLED IN PRODUCTION, IT WILL REVEAL PASSPHRASES IN LOGS
    #dbg "gpg: ${GPG_BINARY} $*"

    if [[ "$*" =~ .*"--passphrase".* ]]; then
        "${GPG_BINARY}" $*
    else
        info "gpg: No file passphrase provided, using repo secret"
        "${GPG_BINARY}" --passphrase="${REPO_GPG_PASSPHRASE}" $*
    fi
}
GPG=gpg_wrapper

source "${SCRIPT_HOME}/libcrypto.sh"

cd "${SCRIPT_HOME}"
echo "cwd: $(pwd)"
mkdir -p Cleartext

function encrypt_all() {
    # Clear out the ciphertext folder
    info "Clearing ciphertext..."
    rm -rf Cipertext/*

    # Encrypt all of the cleartext files
    for clearfile in Cleartext/* ; do
        local clearfilename=$(basename "${clearfile}")
        encrypt_file "${clearfile}" "Ciphertext/${clearfilename}.asc"
    done

    # Re-encrypt passbook
    info "Re-encrypting passbook..."
    encrypt_passbook

    info "Removing cleartext passbook..."
    rm "${PASSBOOK}"
}

function decrypt_all() {
    # Decrypt all of the ciphertext filres
    for cipherfile in Ciphertext/* ; do
        local cipherfilename=$(basename "${cipherfile}" | sed -e 's/\.asc$//')
        if [ -s "Cleartext/${cipherfilename}" ]; then
            info "decrypt_all(): Cleartext/${cipherfilename} exists, not decrypting"
        else
            decrypt_file "${cipherfile}" "Cleartext/${cipherfilename}"
        fi
    done

    info "Removing cleartext passbook..."
    rm "${PASSBOOK}"
}

set +u
OPERATION="$1"
set -u

# If we don't have any passbook yet, start an empty one
if [ ! -e "${PASSBOOK}" ] && [ ! -e "${PASSBOOK}.asc" ]; then
    if [ "${OPERATION}" == "decrypt" ]; then
        fail "Can't decrypt on the first run"
    fi

    info "Creating empty passbook..."
    >"${PASSBOOK}"
fi

# If we don't have the plaintext passbook, create it from ciphertext
if [ ! -e "${PASSBOOK}" ]; then
    info "Decrypting passbook..."
    decrypt_passbook
else
    info "Passbook cleartext exists already"
fi

if [ "$OPERATION" == "encrypt" ]; then
    encrypt_all
elif [ "$OPERATION" == "decrypt" ]; then
    decrypt_all
else
    fail "Usage: $0 encrypt|decrypt"
fi

