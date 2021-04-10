#!/bin/bash

function fail() {
    echo "ERROR: $1" >/dev/stderr
    exit 1
}

function info() {
    echo "INFO: $1"
}

function dbg() {
    echo "DEBUG: $1" >>/dev/stderr
}

function encrypt_passbook() {
    "${GPG}" ${GPG_OPTS} --symmetric --cipher-algo "${GPG_ALGO}" --armor --output "${PASSBOOK}.asc" "${PASSBOOK}"
}

function decrypt_passbook() {
    "${GPG}" ${GPG_OPTS} --output "${PASSBOOK}" --decrypt "${PASSBOOK}.asc"
}

function encrypt_file() {
    if [ "$1" == "" ] || [ "$2" == "" ]; then
        fail "encrypt_file() called without source and destination filenames"
    fi

    info "encrypt_file(): ${1} -> ${2}"

    local FILE_BASENAME="$(basename "${1}")"
    local FILE_PASSPHRASE=$(passphrase_for_file_encrypt "${FILE_BASENAME}")
    "${GPG}" ${GPG_OPTS} --passphrase="${FILE_PASSPHRASE}" --symmetric --cipher-algo "${GPG_ALGO}" --armor --output "${2}" "${1}"
}

function decrypt_file() {
    if [ "$1" == "" ] || [ "$2" == "" ]; then
        fail "decrypt_file() called without source and destination filenames"
    fi

    info "decrypt_file(): ${1} -> ${2}"

    local FILE_BASENAME="$(basename "${1}" | sed -e 's/\.asc$//')"
    local FILE_PASSPHRASE=$(passphrase_for_file_decrypt "${FILE_BASENAME}")
    "${GPG}" ${GPG_OPTS} --passphrase="${FILE_PASSPHRASE}" --output "${2}" --decrypt "${1}"
}

function passphrase_for_file_encrypt() {
    if [ "$1" == "" ]; then
        fail "passphrase_for_file_encrypt() called without filename"
    fi

    local FILENAME
    FILENAME="$1"

    PASSBOOK_LINE="$(grep "$FILENAME " "${PASSBOOK}" || echo "NONE")"
    if [ "${PASSBOOK_LINE}" == "NONE" ]; then
        dbg "passphrase_for_file(): Generating passphrase for $1"
        PASSPHRASE=$(pwgen -s 40 1)
        echo "$1    ${PASSPHRASE}" >>${PASSBOOK}
    else
        PASSPHRASE=$(echo "${PASSBOOK_LINE}" | awk '{ print $2 }')
    fi

    echo "${PASSPHRASE}"
}

function passphrase_for_file_decrypt() {
    if [ "$1" == "" ]; then
        fail "passphrase_for_file_decrypt() called without filename"
    fi

    local FILENAME
    FILENAME="$1"

    PASSBOOK_LINE="$(grep "${FILENAME} " "${PASSBOOK}" || echo "NONE")"
    if [ "${PASSBOOK_LINE}" == "NONE" ]; then
        fail "passphrase_for_file(): No passphrase for ${FILENAME}"
    else
        PASSPHRASE=$(echo "${PASSBOOK_LINE}" | awk '{ print $2 }')
    fi

    echo "${PASSPHRASE}"
}
