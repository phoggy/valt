#!/usr/bin/env bash

# Library to generate PDF files from HTML.
# Intended for use via: require 'valt/pdf'

generatePdf() {
    local htmlFile="${1}"
    local outputFile="${2}"
    local footerTemplate="${3:-}"

    if [ -z "${htmlFile}" ] || [ -z "${outputFile}" ]; then
        fail "Usage: generatePdf <html-file> <output-file> [<footerTemplate>]"
    fi

    # Run from the node-js directory to ensure proper module resolution
    (
        cd "${nodeJsHome}" || fail
        if [ -n "${footerTemplate}" ]; then
            node generate-pdf.js "${htmlFile}" "${outputFile}" "${footerTemplate}" || fail
        else
            node generate-pdf.js "${htmlFile}" "${outputFile}" || fail
        fi
    )
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'valt/pdf' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_valt_pdf() {
    require 'rayvn/core'

    # When running under Nix, use pre-built Puppeteer from the flake
    if [[ -n ${VALT_NIX_NODE_JS_HOME:-} ]]; then
        declare -gr nodeJsHome="${VALT_NIX_NODE_JS_HOME}"
        return 0
    fi

    declare -gr nodeJsHome="${ configDirPath; }/node-js"
    local srcFile="${valtEtcDir}/generate-pdf.js"
    local dstFile="${nodeJsHome}/generate-pdf.js"

    if [ ! -d "${nodeJsHome}" ]; then
        ensureDir "${nodeJsHome}"
        (
            echo "initializing node js"
            cd "${nodeJsHome}" || fail
            npm init -y &>/dev/null || fail
            npm install puppeteer || fail
            cp "${srcFile}" . || fail
        )
    elif [ "${dstFile}" -ot "${srcFile}" ]; then
        cp "${srcFile}" "${dstFile}"
    fi
}
