#!/usr/bin/env bash
# shellcheck disable=SC2155

# Password/phrase breach testing.
# Use via: require 'valt/pwned'

# Check whether a password appears in the HaveIBeenPwned breach database via k-anonymity API.
# Returns 0 if not found, 1 if the API could not be reached, 2 if the password has been breached.
# Args: pass
#
#   pass - plain-text password to check
hasNotBeenPwned() {
    local pass="$1"
    local hash; hash=${ echo -n "${pass}" | shasum | cut -d' ' -f1 | tr '[:lower:]' '[:upper:]'; }
    local prefix=${hash:0:5}
    local suffix=${hash:5}
    local results; results=${ curl -m 10 -s -H 'Add-Padding: true' "${_pwnedPasswordsApiUrl}/range/${prefix}"; }
    if [[ -z ${results} ]]; then
        return 1  # Unable to check
    fi

    local match; match=${ echo "${results}" | grep ${suffix}; }
    if [[ -n ${match} ]]; then
        local count; count=${ echo "${match}" | cut -d':' -f2; }
        if [[ ${count} != 0 ]]; then
            return 2  # has been pwned
        fi
    fi
    return 0 # has not been pwned
}


PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'valt/pwned' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_valt_pwned() {
    declare -grx _pwnedPasswordsApiUrl='https://api.pwnedpasswords.com'
}

