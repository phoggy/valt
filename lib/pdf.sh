#!/usr/bin/env bash

# Generate PDF files from HTML.
# Use via: require 'valt/pdf'

# Generate a PDF file from an HTML file using Puppeteer (Node.js).
# Args: htmlFile outputFile [footerTemplate]
#
#   htmlFile       - path to the input HTML file
#   outputFile     - path where the generated PDF will be written
#   footerTemplate - optional HTML string used as the PDF footer template
generatePdf() {
    local htmlFile="${1}"
    local outputFile="${2}"
    local footerTemplate="${3:-}"

    if [ -z "${htmlFile}" ] || [ -z "${outputFile}" ]; then
        fail "Usage: generatePdf <html-file> <output-file> [<footerTemplate>]"
    fi

    if [ -n "${footerTemplate}" ]; then
        NODE_PATH="${nodeJsHome}/node_modules" node "${valtEtcDir}/generate-pdf.js" "${htmlFile}" "${outputFile}" "${footerTemplate}" || fail
    else
        NODE_PATH="${nodeJsHome}/node_modules" node "${valtEtcDir}/generate-pdf.js" "${htmlFile}" "${outputFile}" || fail
    fi
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'valt/pdf' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_valt_pdf() {
    require 'rayvn/core'

    # VALT_PDF_DEPS_HOME set by Nix wrapProgram; Brew installs directly to config dir.
    declare -gr nodeJsHome="${VALT_PDF_DEPS_HOME:-${ configDirPath node-js; }}"

    [[ -d "${nodeJsHome}/node_modules" ]] || fail "PDF dependencies not found at '${nodeJsHome}'. Reinstall valt."

    # PUPPETEER_EXECUTABLE_PATH set by Nix wrapProgram on Linux (pkgs.chromium).
    # On Nix macOS the download was skipped (PUPPETEER_SKIP_DOWNLOAD + PUPPETEER_SKIP_CHROME_DOWNLOAD),
    # so find a system browser.
    # On Brew, puppeteer finds its own downloaded browser automatically (no env var needed).
    if [[ -n "${VALT_PDF_DEPS_HOME:-}" && -z "${PUPPETEER_EXECUTABLE_PATH:-}" ]]; then
        local candidate
        for candidate in \
            "/Applications/Chromium.app/Contents/MacOS/Chromium" \
            "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"; do
            [[ -x "${candidate}" ]] && { export PUPPETEER_EXECUTABLE_PATH="${candidate}"; break; }
        done
        [[ -n "${PUPPETEER_EXECUTABLE_PATH:-}" ]] || \
            fail "No Chrome/Chromium found for PDF generation. Install Chrome or set PUPPETEER_EXECUTABLE_PATH."
    fi
}
