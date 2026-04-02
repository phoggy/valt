#!/usr/bin/env bash

# Valt deps plugin: scans node/*.js files for npm dependencies and updates node/package.json.
# Invoked automatically by 'rayvn deps valt' via the plugins/deps-plugin.sh convention.

findProjectDeps() {
    local projectName="$1" projectRoot="$2"
    # fixMode="$3" flakeFile="$4" available if needed
    local nodeDir="${projectRoot}/node"
    [[ -d "${nodeDir}" ]] || return 0

    local -a jsFiles=()
    local f
    for f in "${nodeDir}"/*.js; do
        [[ -f "${f}" ]] && jsFiles+=("${f}")
    done
    (( ${#jsFiles[@]} )) || return 0

    show nl "Scanning ${#jsFiles[@]} JS file(s) in node/ for npm dependencies"

    local -a packages=()
    local pkg
    while IFS= read -r pkg; do
        [[ ${pkg} ]] && packages+=("${pkg}")
    done < <( _valtNpmExtractPackages "${jsFiles[@]}" )

    show primary "Found npm package(s): ${packages[*]:-none}"
    (( ${#packages[@]} )) || return 0

    local packageJsonFile="${nodeDir}/package.json"

    # Load existing dependencies from package.json
    local -A existingDeps=()
    if [[ -f "${packageJsonFile}" ]]; then
        local existingPkg ver
        while IFS='=' read -r existingPkg ver; do
            [[ ${existingPkg} ]] && existingDeps["${existingPkg}"]="${ver}"
        done < <( node -e "
            const p = require('${packageJsonFile}');
            Object.entries(p.dependencies||{}).forEach(([k,v])=>console.log(k+'='+v)); # lint-ok
        " 2>/dev/null )
    fi

    # Query npm for versions of new packages
    local -A newDeps=()
    local versionOut
    for pkg in "${packages[@]}"; do
        [[ ${existingDeps[${pkg}]+defined} ]] && continue
        versionOut=${ npm view "${pkg}" version 2>/dev/null; }
        if [[ -z "${versionOut}" ]]; then
            warn "Could not find npm version for '${pkg}', skipping"
            continue
        fi
        newDeps["${pkg}"]="^${versionOut}"
        show success "Found new npm dependency: ${pkg}@^${versionOut}"
    done

    (( ${#newDeps[@]} )) || return 0

    _valtNpmWritePackageJson "${packageJsonFile}" "${projectName}" existingDeps newDeps
}

# Extract npm package names from JS files, filtering Node.js built-ins and relative imports.
_valtNpmExtractPackages() {
    gawk '
        BEGIN {
            split("assert async_hooks buffer child_process cluster console constants crypto dgram diagnostics_channel dns domain events fs http http2 https inspector module net os path perf_hooks process punycode querystring readline repl stream string_decoder sys timers tls trace_events tty url util v8 vm wasi worker_threads zlib", a, " ")
            for (i in a) builtin[a[i]] = 1 # lint-ok
        }
        function extract(line,    full, pkg, lookup, p, n) {
            while (match(line, /(require|from)[ \t(]*[\x22\x27][^\x22\x27]+[\x22\x27]/)) { # lint-ok
                full = substr(line, RSTART, RLENGTH)
                line = substr(line, RSTART + RLENGTH)
                if (!match(full, /[\x22\x27][^\x22\x27]+[\x22\x27]/)) continue # lint-ok
                pkg = substr(full, RSTART + 1, RLENGTH - 2)
                if (pkg ~ /^[.\/]/) continue
                lookup = pkg; sub(/^node:/, "", lookup)
                if (builtin[lookup]) continue
                if (pkg !~ /^@/) { n = split(pkg, p, "/"); pkg = p[1] }
                if (!seen[pkg]++) print pkg
            }
        }
        { extract($0) }
    ' "$@" | sort -u
}

# Write node/package.json with merged existing and new dependencies.
_valtNpmWritePackageJson() {
    local packageJsonFile="$1" projectName="$2"
    local -n _vNpwExistingRef="$3"
    local -n _vNpwNewRef="$4"

    local -A allDeps=()
    local k
    for k in "${!_vNpwExistingRef[@]}"; do allDeps["${k}"]="${_vNpwExistingRef[${k}]}"; done
    for k in "${!_vNpwNewRef[@]}"; do allDeps["${k}"]="${_vNpwNewRef[${k}]}"; done

    local -a sortedKeys=()
    while IFS= read -r k; do
        sortedKeys+=("${k}")
    done < <( printf '%s\n' "${!allDeps[@]}" | sort )

    local tmpFile="${packageJsonFile}.tmp"
    {
        printf '{\n'
        printf '  "name": "%s-node",\n' "${projectName}"
        printf '  "private": true,\n'
        printf '  "dependencies": {\n'
        local i
        for (( i = 0; i < ${#sortedKeys[@]}; i++ )); do
            k="${sortedKeys[${i}]}"
            if (( i + 1 < ${#sortedKeys[@]} )); then
                printf '    "%s": "%s",\n' "${k}" "${allDeps[${k}]}"
            else
                printf '    "%s": "%s"\n' "${k}" "${allDeps[${k}]}"
            fi
        done
        printf '  }\n'
        printf '}\n'
    } > "${tmpFile}" && mv "${tmpFile}" "${packageJsonFile}"

    show success "Updated ${packageJsonFile}"
    show nl "Run 'nix build' to verify, then commit node/package.json and update npmDepsHash in flake.nix"
}
