#!/usr/bin/env bash
# shellcheck disable=SC2155

# Password/phrase breach testing.
# Use via: require 'valt/pwned'

# ◇ Check whether a password appears in the HaveIBeenPwned breach database (via k-anonymity API).
#
# · ARGS
#
#   passwordVar (stringRef)     Name of variable containing the password.
#   apiErrorVar (stringRef)     Name of variable to return any api error.
#   breachCountVar (stringRef)  Name of variable to return the breach count.
#
# Returns 0 if not found, 1 if the API returned an error, 2 if the password has been breached.

hasNotBeenPwned() {
    local -n passRef=$1
    local -n apiErrorRef=$2; apiErrorRef=0
    local -n breachCountRef=$3; breachCountRef=0
debug "passRef: $1, breachCountRef: $2"
    local hash; hash=${ echo -n "${passRef}" | shasum | cut -d' ' -f1 | tr '[:lower:]' '[:upper:]'; }
    local prefix=${hash:0:5}
    local suffix=${hash:5}
    local results; results=${ curl -m 10 -s -H 'Add-Padding: true' "${_pwnedPasswordsApiUrl}/range/${prefix}"; }
    local apiResult=$?
    apiErrorRef=${apiResult}
debugVar apiResult
    if (( apiResult )); then
        debug "pwned api failed: ${apiResult}"
        return 1  # Unable to check
    fi

    local match; match=${ echo "${results}" | grep ${suffix}; }
    if [[ -n ${match} ]]; then
        local count; count=${ trim "${match#*:}"; }
        if (( count > 0 )); then
            breachCountRef="${count}"
            debug "pwned breach count: ${count}"
            return 2  # has been pwned
        fi
    fi
    debug "pwned not breached"
    return 0 # has not been pwned
}


PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'valt/pwned' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

# Map a curl exit code (as returned via hasNotBeenPwned's apiErrorVar) to a short,
# user-friendly description, so callers don't have to show a bare number. Falls back to a
# generic "curl error N" for codes not covered here — see 'man curl' EXIT CODES for the full
# list; this covers the ones actually plausible for a simple HTTPS GET like the pwned check.
_curlErrorMessage() {
    local code="$1"
    local -A messages=(
        [1]='unsupported protocol'
        [3]='malformed URL'
        [5]='could not resolve proxy'
        [6]='could not resolve host'
        [7]='could not connect to host'
        [18]='transfer ended prematurely'
        [22]='server returned an HTTP error'
        [26]='local read error'
        [28]='request timed out'
        [35]='SSL connection failed'
        [47]='too many redirects'
        [52]='server returned an empty response'
        [55]='failed sending data'
        [56]='failed receiving data'
        [60]='SSL certificate could not be verified'
        [67]='login denied'
        [77]='problem reading SSL CA certificate'
        [78]='remote resource not found'
        [91]='SSL client certificate error'
    )
    echo "${messages[${code}]:-curl error ${code}}"
}

_init_valt_pwned() {
    declare -grx _pwnedPasswordsApiUrl='https://api.pwnedpasswords.com'
}

