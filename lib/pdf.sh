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
    local htmlFile="$1"
    local outputFile="$2"
    local footerTemplate="${3:-}"

    if [[ -z ${htmlFile} ]] || [[ -z ${outputFile} ]]; then
        fail "Usage: generatePdf <html-file> <output-file> [<footerTemplate>]"
    fi

    if [[ -n "${footerTemplate}" ]]; then
        executeNodeScript valt generate-pdf.js "${htmlFile}" "${outputFile}" "${footerTemplate}" || fail
    else
        executeNodeScript valt generate-pdf.js "${htmlFile}" "${outputFile}" || fail
    fi
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'valt/pdf' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_valt_pdf() {
    require 'valt/node'

    requireNodeModules valt VALT_PDF_DEPS_HOME

    # PUPPETEER_EXECUTABLE_PATH set by Nix wrapProgram on Linux (pkgs.chromium).
    # On macOS (Nix or dev), Chrome download is skipped so find a system browser.
    if [[ -z "${PUPPETEER_EXECUTABLE_PATH:-}" ]]; then
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
