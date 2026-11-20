#!/usr/bin/env bash

main() {
    init "$@"

    # Archive creation
    testBasicArchiveCreation
    testOuterArchiveStructure
    testPubArchiveStructure
    testExtractPublicArchive
    testEncryptedArchiveStructure
    testPayloadContents
    testSignaturesVerify
    testVerifySecureArchive
    testVerifyFailsOnTamperedOuter
    testVerifyFailsOnTamperedPayload
    testVerifyMissingArchiveFails
    testVerifyMissingIdentityFails

    # README content
    testPublicReadmeStructure
    testPublicReadmeRecoverCommand
    testPublicReadmeNoNotes
    testPublicReadmeWithNotes
    testPrivateReadmeStructure
    testPrivateReadmeNoNotes
    testPrivateReadmeWithNotes

    # Options
    testForceOverwrite
    testNoForceFailsOnConflict
    testCustomName
    testDefaultTimeZoneIsLocal
    testMacMetadataKeptByDefault
    testNoMacMetadata
    testNoPublicCompanion
    testCustomOutputDir

    # Extract
    testExtractSecureArchive
    testExtractSecureArchiveCustomOutputDir
    testExtractSecureArchiveFailsOnTamperedOuter

    # Manifests
    testManifestInsideEncryptionAndSigned
    testDefaultManifest
    testInvalidManifestRejected
    testManifestHandlerDecidesExtraction
    testDefaultManifestHandled
    testRestorePathways
    testShowRestoreCommands
    testArchiveBrewTap
    testReadmeRestoreSection
    testDecryptCommandRestoresInsteadOfExtracting

    # Included files
    testIncludeDirectory
    testIncludedFilesOpen
    testIncludeExtraRecipientAccepted
    testIncludeRefusesOtherSigner
    testIncludeRefusesUnopenable
    testIncludeRequiresSignature
    testIncludeRejectsOtherFiles
    testIncludeMaxAge
    testIncludeRepeatedArchiveNames
    testIncludeEmptyDirectory
    testIncludeNote
    testIncludeEmptyNoteFails
    testDiskTempWarns

    # Validation
    testMissingIdentityFails
    testMissingRecipientFails
    testMissingInputFails

    return 0
}

init() {
    while (( $# )); do
        case "$1" in
            --debug*) setDebug "$@"; shift $? ;;
        esac
        shift
    done

    rayvnTest_ValtKeyPassphrase='valt-test-passphrase-12345'
    skipKeyPassphraseAdvice=1
    skipReadPasswordStrength=1

    declare -g pubFile keyFile testInputDir archiveOutputDir archiveFile archivePubFile
    declare -g outerExtractDir innerExtractDir payloadExtractDir

    local testKeyDir; testKeyDir="${ makeTempDir; }"
    newValtKeys 'test' "${testKeyDir}" pubFile keyFile
    declare -g otherPubFile otherKeyFile # another key pair, for included files that break the rule
    newValtKeys 'other' "${testKeyDir}" otherPubFile otherKeyFile

    testInputDir="${ makeTempDir; }"
    echo 'hello from file1' > "${testInputDir}/file1.txt"
    echo 'hello from file2' > "${testInputDir}/file2.txt"
    mkdir -p "${testInputDir}/subdir"
    echo 'nested content' > "${testInputDir}/subdir/file3.txt"

    archiveOutputDir="${ makeTempDir; }"
    archiveFile="${ newSecureArchive -C "${testInputDir}" file1.txt file2.txt subdir -i "${keyFile}" -R "${pubFile}" -n test -o "${archiveOutputDir}"; }"
    archivePubFile="${archiveFile}.pub"

    # Extract layers once for reuse across tests
    outerExtractDir="${ makeTempDir; }"
    tar xJf "${archiveFile}" -C "${outerExtractDir}" || fail "failed to extract outer archive"

    innerExtractDir="${ makeTempDir; }"
    decrypt -i "${keyFile}" -o "${innerExtractDir}/decrypted.tar.xz" "${outerExtractDir}/${_archiveEncryptedName}" || fail
    tar xJf "${innerExtractDir}/decrypted.tar.xz" -C "${innerExtractDir}" || fail "failed to expand inner archive"

    payloadExtractDir="${ makeTempDir; }"
    tar xJf "${innerExtractDir}/${_archivePayloadName}" -C "${payloadExtractDir}" || fail "failed to extract payload"
}

# ─── Creation ────────────────────────────────────────────────────────────────

testBasicArchiveCreation() {
    assertFile "${archiveFile}"
    assertFile "${archivePubFile}"
    assertContains 'test-' "${archiveFile}"
    assertContains '.valt' "${archiveFile}"
}

testOuterArchiveStructure() {
    assertFile "${outerExtractDir}/${_archiveEncryptedName}"
    assertFile "${outerExtractDir}/${_archiveEncryptedSigName}"
    assertFile "${outerExtractDir}/${_archiveSigPubName}"
    assertFile "${outerExtractDir}/${_archiveAgePubName}"
    assertFile "${outerExtractDir}/${_archiveReadMeName}"
}

testPubArchiveStructure() {
    local pubExtractDir; pubExtractDir="${ makeTempDir; }"
    tar xJf "${archivePubFile}" -C "${pubExtractDir}" || fail "failed to extract pub archive"
    assertFile "${pubExtractDir}/${_archiveEncryptedSigName}"
    assertFile "${pubExtractDir}/${_archiveSigPubName}"
    assertFile "${pubExtractDir}/${_archiveAgePubName}"
    assertFile "${pubExtractDir}/${_archiveReadMeName}"
    assertFalse "pub archive must not contain encrypted tar" test -f "${pubExtractDir}/${_archiveEncryptedName}"
}

testExtractPublicArchive() {
    local outputDir; outputDir="${ makeTempDir; }"
    local file; file="${ newSecureArchive -C "${testInputDir}" file1.txt \
        -i "${keyFile}" -R "${pubFile}" -n pub-extract -o "${outputDir}"; }"
    rm "${file}.pub" || fail "test setup: failed to remove existing pub archive"

    extractPublicArchive "${file}"

    local pubArchive="${file}.pub"
    assertFile "${pubArchive}"
    local extractDir; extractDir="${ makeTempDir; }"
    tar xJf "${pubArchive}" -C "${extractDir}" || fail
    assertFile "${extractDir}/${_archiveEncryptedSigName}"
    assertFile "${extractDir}/${_archiveSigPubName}"
    assertFile "${extractDir}/${_archiveAgePubName}"
    assertFile "${extractDir}/${_archiveReadMeName}"
    assertFalse "pub archive must not contain encrypted tar" test -f "${extractDir}/${_archiveEncryptedName}"
}

testEncryptedArchiveStructure() {
    assertFile "${innerExtractDir}/${_archivePayloadName}"
    assertFile "${innerExtractDir}/${_archivePayloadSigName}"
    assertFile "${innerExtractDir}/${_archiveSigPubName}"
    assertFile "${innerExtractDir}/${_archiveAgePubName}"
    assertFile "${innerExtractDir}/${_archiveReadMeName}"
}

testPayloadContents() {
    assertFile "${payloadExtractDir}/file1.txt"
    assertFile "${payloadExtractDir}/file2.txt"
    assertFile "${payloadExtractDir}/subdir/file3.txt"
    assertInFile 'hello from file1' "${payloadExtractDir}/file1.txt"
    assertInFile 'nested content' "${payloadExtractDir}/subdir/file3.txt"
}

testSignaturesVerify() {
    assertTrue "outer signature must verify" \
        verifyFileSignature "${pubFile}" \
                            "${outerExtractDir}/${_archiveEncryptedName}" \
                            "${outerExtractDir}/${_archiveEncryptedSigName}"
    assertTrue "payload signature must verify" \
        verifyFileSignature "${pubFile}" \
                            "${innerExtractDir}/${_archivePayloadName}" \
                            "${innerExtractDir}/${_archivePayloadSigName}"
}

testVerifySecureArchive() {
    verifySecureArchive "${archiveFile}" -i "${keyFile}"
}

testVerifyFailsOnTamperedOuter() {
    local tamperDir; tamperDir="${ makeTempDir; }"
    tar xJf "${archiveFile}" -C "${tamperDir}" || fail
    echo 'tampered' >> "${tamperDir}/${_archiveEncryptedName}"
    local tamperedArchive="${tamperDir}/tampered.valt"
    tar cJf "${tamperedArchive}" -C "${tamperDir}" "${_archiveFiles[@]}" || fail
    ( verifySecureArchive "${tamperedArchive}" -i "${keyFile}" ) 2> /dev/null \
        && fail "must fail when encrypted archive is tampered"
    return 0
}

testVerifyFailsOnTamperedPayload() {
    local outerDir; outerDir="${ makeTempDir; }"
    tar xJf "${archiveFile}" -C "${outerDir}" || fail

    # Decrypt, tamper with payload, re-encrypt, re-sign
    local innerDir; innerDir="${ makeTempDir; }"
    decrypt -i "${keyFile}" -o "${innerDir}/decrypted.tar.xz" "${outerDir}/${_archiveEncryptedName}" || fail
    tar xJf "${innerDir}/decrypted.tar.xz" -C "${innerDir}" || fail
    echo 'tampered' >> "${innerDir}/${_archivePayloadName}"

    # Re-package the tampered inner tar (without re-signing) and re-encrypt
    local r; r="${ recipient "${keyFile}"; }"
    tar cJf - -C "${innerDir}" "${_archiveEncryptedFiles[@]}" \
        | encrypt -r "${r}" -o "${outerDir}/${_archiveEncryptedName}" || fail
    signFile "${keyFile}" "${outerDir}/${_archiveEncryptedName}" \
             "${outerDir}/${_archiveEncryptedSigName}" || fail

    local tamperedArchive="${outerDir}/tampered-payload.valt"
    tar cJf "${tamperedArchive}" -C "${outerDir}" "${_archiveFiles[@]}" || fail
    ( verifySecureArchive "${tamperedArchive}" -i "${keyFile}" ) 2> /dev/null \
        && fail "must fail when payload is tampered"
    return 0
}

testVerifyMissingArchiveFails() {
    ( verifySecureArchive "/nonexistent/path.valt" -i "${keyFile}" ) 2> /dev/null \
        && fail "must fail with nonexistent archive"
    return 0
}

testVerifyMissingIdentityFails() {
    ( verifySecureArchive "${archiveFile}" ) 2> /dev/null \
        && fail "must fail without identity"
    return 0
}

# ─── README ──────────────────────────────────────────────────────────────────

testPublicReadmeStructure() {
    local readme="${outerExtractDir}/${_archiveReadMeName}"
    assertInFile 'SECURE ARCHIVE' "${readme}"
    assertInFile 'test-' "${readme}"
    assertInFile "${USER}@" "${readme}"
    assertInFile 'encrypted.tar.xz.age' "${readme}"
    assertInFile 'Extract with valt' "${readme}"
    assertInFile 'Extract Manually' "${readme}"
    assertInFile 'age -d' "${readme}"
    assertInFile 'minisign -V' "${readme}"
}

# The README says how to recover with Nix: with the valt release current when it was made (see valtReleaseTag), and
# with the latest version

testPublicReadmeRecoverCommand() {
    local readme="${outerExtractDir}/${_archiveReadMeName}"
    assertInFile 'Extract with Nix' "${readme}"
    assertInFile "nix run github:phoggy/valt/${ valtReleaseTag; }#recover -- decrypt test-" "${readme}"
    assertInFile 'nix run github:phoggy/valt#recover -- decrypt test-' "${readme}"
    assertNotInFile '${RECOVER_COMMANDS}' "${readme}"
    assertNotInFile 'phoggy.github.io' "${readme}"
}

testPublicReadmeNoNotes() {
    assertNotInFile '▋ Notes' "${outerExtractDir}/${_archiveReadMeName}"
}

testPublicReadmeWithNotes() {
    local outputDir; outputDir="${ makeTempDir; }"
    local file; file="${ newSecureArchive -C "${testInputDir}" file1.txt file2.txt subdir \
        -i "${keyFile}" -R "${pubFile}" -n noted -o "${outputDir}" -u 'keep these files safe'; }"
    local extractDir; extractDir="${ makeTempDir; }"
    tar xJf "${file}" -C "${extractDir}" || fail
    assertInFile '▋ Notes' "${extractDir}/${_archiveReadMeName}"
    assertInFile 'keep these files safe' "${extractDir}/${_archiveReadMeName}"
}

testPrivateReadmeStructure() {
    local readme="${innerExtractDir}/${_archiveReadMeName}"
    assertInFile 'SECURE ARCHIVE CONTENTS' "${readme}"
    assertInFile 'test-' "${readme}"
    assertInFile "${USER}@" "${readme}"
    assertInFile 'payload.tar' "${readme}"
    assertInFile 'Verify' "${readme}"
    assertInFile 'minisign -V' "${readme}"
    assertNotInFile 'age -d' "${readme}"
}

testPrivateReadmeNoNotes() {
    assertNotInFile '▋ Notes' "${innerExtractDir}/${_archiveReadMeName}"
}

testPrivateReadmeWithNotes() {
    local outputDir; outputDir="${ makeTempDir; }"
    local file; file="${ newSecureArchive -C "${testInputDir}" file1.txt file2.txt subdir \
        -i "${keyFile}" -R "${pubFile}" -n noted-private -o "${outputDir}" -u 'private note here'; }"
    local outerDir; outerDir="${ makeTempDir; }"
    tar xJf "${file}" -C "${outerDir}" || fail
    local innerDir; innerDir="${ makeTempDir; }"
    decrypt -i "${keyFile}" -o "${innerDir}/decrypted.tar.xz" "${outerDir}/${_archiveEncryptedName}" || fail
    tar xJf "${innerDir}/decrypted.tar.xz" -C "${innerDir}" || fail
    assertInFile '▋ Notes' "${innerDir}/${_archiveReadMeName}"
    assertInFile 'private note here' "${innerDir}/${_archiveReadMeName}"
}

# ─── Options ─────────────────────────────────────────────────────────────────

# Archive names include a timestamp to the second. Tests that predict a name start at the beginning of a second, so the
# archive is created within the same second.

waitForNewSecond() {
    local second; second="${ date '+%S'; }"
    while [[ ${ date '+%S'; } == "${second}" ]]; do
        sleep 0.05
    done
}

testForceOverwrite() {
    local outputDir; outputDir="${ makeTempDir; }"
    waitForNewSecond
    local ts; ts="${ timeStamp UTC; }"
    touch "${outputDir}/overwrite-${ts}.valt" "${outputDir}/overwrite-${ts}.valt.pub"
    local file; file="${ newSecureArchive -C "${testInputDir}" file1.txt \
        -i "${keyFile}" -R "${pubFile}" -n overwrite -z UTC -o "${outputDir}" --force; }"
    assertFile "${file}"
}

testNoForceFailsOnConflict() {
    local outputDir; outputDir="${ makeTempDir; }"
    waitForNewSecond
    local ts; ts="${ timeStamp UTC; }"
    touch "${outputDir}/conflict-${ts}.valt"
    ( newSecureArchive -C "${testInputDir}" file1.txt \
        -i "${keyFile}" -R "${pubFile}" -n conflict -z UTC -o "${outputDir}" ) 2> /dev/null \
        && fail "must fail when archive already exists"
    return 0
}

testDefaultTimeZoneIsLocal() {
    local outputDir; outputDir="${ makeTempDir; }"
    local file; file="${ newSecureArchive -C "${testInputDir}" file1.txt -i "${keyFile}" -R "${pubFile}" -n zone -o "${outputDir}"; }"
    [[ ${file} == "${outputDir}"/zone-*_"${ date '+%Z'; }".valt ]] || fail "the archive name must use the local time zone: ${file}"
}

# macOS metadata (here a Finder tag) of the INPUT files is kept unless --no-mac-metadata, and never kept for the
# archive's own files. macOS only: other systems' tar does not record it.

newTaggedArchive() {
    local -n taggedArchiveRef=$1; shift
    local inputDir; inputDir="${ makeTempDir; }"
    echo 'tagged' > "${inputDir}/tagged.txt"
    xattr -w com.apple.metadata:_kMDItemUserTags '("Red\n6")' "${inputDir}/tagged.txt" || fail
    local outputDir; outputDir="${ makeTempDir; }"
    taggedArchiveRef="${ newSecureArchive -C "${inputDir}" tagged.txt -i "${keyFile}" -R "${pubFile}" -n tagged -o "${outputDir}" "$@"; }"
    local metadataHeaders; metadataHeaders="${ xz -dc "${taggedArchiveRef}" | grep -ac 'LIBARCHIVE.xattr'; }"
    assertEqual 0 "${metadataHeaders}" "the archive's own files must have no macOS metadata"
}

testMacMetadataKeptByDefault() {
    (( onMacOS && _bsdTar )) && command -v xattr > /dev/null || return 0 # only macOS tar keeps it (not GNU tar, e.g. in Nix)
    local archive; newTaggedArchive archive
    local destDir; destDir="${ makeTempDir; }"
    extractSecureArchive -i "${keyFile}" -o "${destDir}" "${archive}" > /dev/null 2>&1 || fail "extract failed"
    assertContains '_kMDItemUserTags' "${ xattr "${destDir}/tagged.txt"; }" "the Finder tag must be kept by default"
}

testNoMacMetadata() {
    (( onMacOS )) && command -v xattr > /dev/null || return 0
    local archive; newTaggedArchive archive --no-mac-metadata
    local destDir; destDir="${ makeTempDir; }"
    extractSecureArchive -i "${keyFile}" -o "${destDir}" "${archive}" > /dev/null 2>&1 || fail "extract failed"
    assertEqual 'tagged' "${ cat "${destDir}/tagged.txt"; }"
    [[ ${ xattr "${destDir}/tagged.txt"; } != *_kMDItemUserTags* ]] || fail "--no-mac-metadata must drop the Finder tag"
}

testNoPublicCompanion() {
    local outputDir; outputDir="${ makeTempDir; }"
    local file; file="${ newSecureArchive -C "${testInputDir}" file1.txt -i "${keyFile}" -R "${pubFile}" -n nopub -o "${outputDir}" --no-public; }"
    assertFile "${file}"
    assertFileDoesNotExist "${file}.pub"
}

testCustomName() {
    local outputDir; outputDir="${ makeTempDir; }"
    local file; file="${ newSecureArchive "${testInputDir}" -i "${keyFile}" -R "${pubFile}" \
        -n myarchive -o "${outputDir}"; }"
    assertContains 'myarchive-' "${file}"
}

testCustomOutputDir() {
    local outputDir; outputDir="${ makeTempDir; }"
    local file; file="${ newSecureArchive "${testInputDir}" -i "${keyFile}" -R "${pubFile}" \
        -n outdir-test -o "${outputDir}"; }"
    assertContains "${outputDir}" "${file}"
    assertFile "${file}"
}

# ─── Extract ─────────────────────────────────────────────────────────────────

testExtractSecureArchive() {
    local outputDir; outputDir="${ makeTempDir; }"
    extractSecureArchive "${archiveFile}" -i "${keyFile}" -o "${outputDir}"
    assertFile "${outputDir}/file1.txt"
    assertFile "${outputDir}/file2.txt"
    assertFile "${outputDir}/subdir/file3.txt"
    assertInFile 'hello from file1' "${outputDir}/file1.txt"
    assertInFile 'nested content' "${outputDir}/subdir/file3.txt"
}

testExtractSecureArchiveCustomOutputDir() {
    local outputDir; outputDir="${ makeTempDir; }"
    extractSecureArchive "${archiveFile}" -i "${keyFile}" -o "${outputDir}"
    assertFile "${outputDir}/file1.txt"
}

testExtractSecureArchiveFailsOnTamperedOuter() {
    local tamperDir; tamperDir="${ makeTempDir; }"
    tar xJf "${archiveFile}" -C "${tamperDir}" || fail
    echo 'tampered' >> "${tamperDir}/${_archiveEncryptedName}"
    local tamperedArchive="${tamperDir}/tampered-extract.valt"
    tar cJf "${tamperedArchive}" -C "${tamperDir}" "${_archiveFiles[@]}" || fail
    local outputDir; outputDir="${ makeTempDir; }"
    ( extractSecureArchive "${tamperedArchive}" -i "${keyFile}" -o "${outputDir}" ) 2> /dev/null \
        && fail "must fail when encrypted archive is tampered"
    return 0
}

# ─── Validation ──────────────────────────────────────────────────────────────

testMissingIdentityFails() {
    ( newSecureArchive "${testInputDir}" -R "${pubFile}" ) 2> /dev/null \
        && fail "must fail without identity"
    return 0
}

testMissingRecipientFails() {
    ( newSecureArchive "${testInputDir}" -i "${keyFile}" ) 2> /dev/null \
        && fail "must fail without recipient"
    return 0
}

testMissingInputFails() {
    ( newSecureArchive -i "${keyFile}" -R "${pubFile}" ) 2> /dev/null \
        && fail "must fail without input files"
    return 0
}

# Verifying or extracting without RAM-backed temp storage warns that the archive is decrypted on disk

testDiskTempWarns() {
    local archive; archive="${ newSecureArchive -C "${testInputDir}" file1.txt -i "${keyFile}" -R "${pubFile}" -n disk \
        -o "${ makeTempDir; }" 2> /dev/null; }" || fail "creating the archive failed"
    local output; output="${ (
        makeSecureTempDir() {
            local -n _dirRef=$1
            _dirRef="${ makeTempDir; }"
            [[ -n ${2:-} ]] && { local -n _ramRef=$2; _ramRef=0; }
            return 0
        }
        extractSecureArchive -i "${keyFile}" -o "${ makeTempDir; }" "${archive}" > /dev/null
        verifySecureArchive -i "${keyFile}" "${archive}" > /dev/null
    ) 2>&1; }" || fail "extracting with disk temp storage failed: ${output}"
    assertContains 'the archive is decrypted in a temporary directory on disk' "${output}"
    (( ${ grep -c 'decrypted in a temporary directory on disk' <<< "${output}"; } == 2 )) ||
        fail "both extract and verify must warn: ${output}"
    output="${ extractSecureArchive -i "${keyFile}" -o "${ makeTempDir; }" "${archive}" 2>&1 > /dev/null; }"
    [[ ${output} != *'on disk'* ]] || fail "RAM-backed storage must not warn"
}

# ─── Included files ──────────────────────────────────────────────────────────

# Writes FILE.age encrypted to the given recipient files and signed with the given key (as valt encrypt does).

newIncludeAgeFile() {
    local file="$1" signingKey="$2"
    shift 2
    local -a recipientArgs=()
    local recipientFile
    for recipientFile in "$@"; do recipientArgs+=(-R "${recipientFile}"); done
    echo "secret in ${file##*/}" > "${file}"
    encrypt "${file}" "${recipientArgs[@]}" -o "${file}.age" || fail
    signFile "${signingKey}" "${file}.age" || fail
    rm "${file}"
}

# Creates an archive of the test input with the given args (e.g. --include), and opens it, setting the named vars to
# the inner (decrypted) and payload directories.

newIncludingArchive() {
    local -n _niaInnerRef=$1
    local -n _niaPayloadRef=$2
    shift 2
    local archive; archive="${ newSecureArchive -C "${testInputDir}" file1.txt -i "${keyFile}" -R "${pubFile}" -n incl \
        -o "${ makeTempDir; }" "$@" 2> /dev/null; }" || fail "creating an archive with included files failed"
    _niaInnerRef="${ makeTempDir; }"
    _niaPayloadRef="${ makeTempDir; }"
    local outer; outer="${ makeTempDir; }"
    tar xJf "${archive}" -C "${outer}" || fail
    decrypt -i "${keyFile}" -o "${_niaInnerRef}/decrypted.tar.xz" "${outer}/${_archiveEncryptedName}" || fail
    tar xJf "${_niaInnerRef}/decrypted.tar.xz" -C "${_niaInnerRef}" || fail
    tar xf "${_niaInnerRef}/${_archivePayloadName}" -C "${_niaPayloadRef}" || fail
}

# Outputs what creating an archive of the test input with the given args says (or fails with), and its status.

includeOutput() {
    ( newSecureArchive -C "${testInputDir}" file1.txt -i "${keyFile}" -R "${pubFile}" -n incl -o "${ makeTempDir; }" \
        "$@" > /dev/null ) 2>&1
}

# A directory's .age and .valt files are included under included/, still encrypted, with each .age file's signature,
# listed in the manifest and the private README, but not the public one

testIncludeDirectory() {
    local dir; dir="${ makeTempDir; }"
    newIncludeAgeFile "${dir}/tokens.2fas" "${keyFile}" "${pubFile}"
    newSecureArchive -C "${testInputDir}" file2.txt -i "${keyFile}" -R "${pubFile}" -n nested -o "${dir}" > /dev/null || fail
    echo 'not included' > "${dir}/notes.txt"
    local inner payload; newIncludingArchive inner payload --include "${dir}"

    assertFile "${payload}/file1.txt"
    assertFile "${payload}/${_archiveIncludedDirName}/tokens.2fas.age"
    assertFile "${payload}/${_archiveIncludedDirName}/tokens.2fas.age.minisig"
    local nested; nested=("${payload}/${_archiveIncludedDirName}"/nested-*.valt)
    assertFile "${nested[0]}"
    [[ ! -e ${payload}/${_archiveIncludedDirName}/notes.txt ]] || fail "only .age and .valt files must be included"

    local manifest="${inner}/${_archiveManifestName}"
    assertEqual 'age valt' "${ jq -r '[.included[].type] | sort | join(" ")' "${manifest}"; }"
    assertEqual "${_archiveIncludedDirName}/tokens.2fas.age" "${ jq -r '.included[] | select(.type == "age") | .path' \
        "${manifest}"; }"
    [[ ${ jq -r '.included[0].modified' "${manifest}"; } =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]] || fail "modified must be a time"

    local readme; readFile "${inner}/${_archiveReadMeName}" readme
    assertContains '▋ Included' "${readme}"
    assertContains "${_archiveIncludedDirName}/tokens.2fas.age  (age, modified" "${readme}"
    local outer; outer="${ makeTempDir; }"
    tar xJf "${ newSecureArchive -C "${testInputDir}" file1.txt -i "${keyFile}" -R "${pubFile}" -n pub -o "${ makeTempDir; }" \
        --include "${dir}" 2> /dev/null; }" -C "${outer}" || fail
    readFile "${outer}/${_archiveReadMeName}" readme
    [[ ${readme} != *'▋ Included'* ]] || fail "the public README must not list the included files"
}

# Included files open with the archive's key, as they were

testIncludedFilesOpen() {
    local dir; dir="${ makeTempDir; }"
    newIncludeAgeFile "${dir}/tokens.2fas" "${keyFile}" "${pubFile}"
    local inner payload; newIncludingArchive inner payload --include "${dir}/tokens.2fas.age"
    local included="${payload}/${_archiveIncludedDirName}/tokens.2fas.age"
    verifyFileSignature "${keyFile}" "${included}"
    assertEqual 'secret in tokens.2fas' "${ decrypt -i "${keyFile}" "${included}"; }"
}

# Other recipients are fine, as long as the archive's key is one of them

testIncludeExtraRecipientAccepted() {
    local dir; dir="${ makeTempDir; }"
    newIncludeAgeFile "${dir}/shared.txt" "${keyFile}" "${pubFile}" "${otherPubFile}"
    local inner payload; newIncludingArchive inner payload --include "${dir}/shared.txt.age"
    assertFile "${payload}/${_archiveIncludedDirName}/shared.txt.age"
}

# A file signed by another key is refused, though the archive's key can open it: anyone can encrypt to a public key

testIncludeRefusesOtherSigner() {
    local dir; dir="${ makeTempDir; }"
    newIncludeAgeFile "${dir}/forged.txt" "${otherKeyFile}" "${pubFile}"
    local output; output="${ includeOutput --include "${dir}/forged.txt.age"; }" && fail "must fail on another signer"
    assertContains 'is not signed by this key' "${output}"

    newSecureArchive -C "${testInputDir}" file2.txt -i "${otherKeyFile}" -R "${pubFile}" -n forged -o "${dir}" > /dev/null || fail
    rm "${dir}"/forged.txt.age*
    output="${ includeOutput --include "${dir}"; }" && fail "must fail on an archive by another signer"
    assertContains 'is not signed by this key' "${output}"
}

# A file the archive's key cannot open is refused, though signed by it

testIncludeRefusesUnopenable() {
    local dir; dir="${ makeTempDir; }"
    newIncludeAgeFile "${dir}/elsewhere.txt" "${keyFile}" "${otherPubFile}"
    local output; output="${ includeOutput --include "${dir}/elsewhere.txt.age"; }" && fail "must fail when it cannot open"
    assertContains 'cannot be opened with this key' "${output}"
}

testIncludeRequiresSignature() {
    local dir; dir="${ makeTempDir; }"
    newIncludeAgeFile "${dir}/unsigned.txt" "${keyFile}" "${pubFile}"
    rm "${dir}/unsigned.txt.age.minisig"
    local output; output="${ includeOutput --include "${dir}"; }" && fail "must fail without a signature"
    assertContains 'has no signature' "${output}"
}

testIncludeRejectsOtherFiles() {
    local file; file="${ makeTempDir; }/plain.txt"
    echo 'plain' > "${file}"
    local output; output="${ includeOutput --include "${file}"; }" && fail "must fail on a file that is not encrypted"
    assertContains 'not a .valt or .age file' "${output}"
    output="${ includeOutput --include "${file}.missing"; }" && fail "must fail on a missing file"
    assertContains 'not found' "${output}"
}

# Says what is included and how long ago it was modified, warning when that is longer ago than --include-max-age

testIncludeMaxAge() {
    local dir; dir="${ makeTempDir; }"
    newIncludeAgeFile "${dir}/tokens.2fas" "${keyFile}" "${pubFile}"
    local output; output="${ includeOutput --include "${dir}" --include-max-age 90; }" || fail "${output}"
    assertContains 'tokens.2fas.age (with its signature, modified today)' "${output}"
    touch -t 202001010000 "${dir}/tokens.2fas.age"
    output="${ includeOutput --include "${dir}" --include-max-age 90; }" || fail "${output}"
    assertContains 'is it up to date?' "${output}"
    output="${ includeOutput --include "${dir}"; }" || fail "${output}"
    [[ ${output} != *'is it up to date?'* ]] || fail "there is no age limit by default"
}

testIncludeRepeatedArchiveNames() {
    local dir; dir="${ makeTempDir; }"
    newSecureArchive -C "${testInputDir}" file1.txt -i "${keyFile}" -R "${pubFile}" -n tokens -o "${dir}" > /dev/null || fail
    waitForNewSecond
    newSecureArchive -C "${testInputDir}" file1.txt -i "${keyFile}" -R "${pubFile}" -n tokens -o "${dir}" > /dev/null || fail
    local output; output="${ includeOutput --include "${dir}"; }" || fail "${output}"
    assertContains '2 archives named tokens-*' "${output}"
}

testIncludeEmptyDirectory() {
    local output; output="${ includeOutput --include "${ makeTempDir; }"; }" || fail "an empty directory is not an error"
    assertContains 'no .valt or .age files' "${output}"
}

# A FILE.note is included with the file, in the manifest and the README, and shown by showIncludedFiles

testIncludeNote() {
    local dir; dir="${ makeTempDir; }"
    newIncludeAgeFile "${dir}/tokens.2fas" "${keyFile}" "${pubFile}"
    newIncludeAgeFile "${dir}/other.txt" "${keyFile}" "${pubFile}"
    printf 'Authenticator tokens.\nImport them in the app.\n' > "${dir}/tokens.2fas.age.note"
    local output; output="${ includeOutput --include "${dir}"; }" || fail "${output}"
    assertContains 'tokens.2fas.age (with its signature and note, modified today)' "${output}"
    assertContains 'other.txt.age (with its signature, modified today)' "${output}"

    local inner payload; newIncludingArchive inner payload --include "${dir}"
    local included="${payload}/${_archiveIncludedDirName}"
    assertFile "${included}/tokens.2fas.age.note"
    local manifest="${inner}/${_archiveManifestName}"
    assertEqual $'Authenticator tokens.\nImport them in the app.' "${ jq -j '.included[] | select(.path |
        endswith("tokens.2fas.age")) | .note' "${manifest}"; }"
    assertEqual 'null' "${ jq -r '.included[] | select(.path | endswith("other.txt.age")) | .note' "${manifest}"; }"

    local readme; readFile "${inner}/${_archiveReadMeName}" readme
    assertContains $'tokens.2fas.age  (age, modified' "${readme}"
    assertContains $'        Authenticator tokens.\n        Import them in the app.' "${readme}"

    output="${ showIncludedFiles "${included}" 2>&1; }"
    assertContains 'tokens.2fas.age' "${output}"
    assertContains 'Import them in the app.' "${output}"
    assertContains 'other.txt.age' "${output}"
    assertEqual '' "${ showIncludedFiles "${ makeTempDir; }"; }"
}

testIncludeEmptyNoteFails() {
    local dir; dir="${ makeTempDir; }"
    newIncludeAgeFile "${dir}/tokens.2fas" "${keyFile}" "${pubFile}"
    printf '\n' > "${dir}/tokens.2fas.age.note"
    local output; output="${ includeOutput --include "${dir}"; }" && fail "must fail on an empty note"
    assertContains 'is empty' "${output}"
}

# ─── Manifests ───────────────────────────────────────────────────────────────

# Writes a wardn-like manifest to a file, setting the named var to its path; with 'no-nix', it offers no Nix way.

newManifestFile() {
    local -n _nmfRef=$1
    local nix='"nix": "github:phoggy/wardn/v0.2.0#restore",'
    [[ ${2:-} == no-nix ]] && nix=''
    _nmfRef="${ makeTempDir; }/manifest.json"
    cat > "${_nmfRef}" << MANIFEST
{ "kind": "wardn vault backup", "tool": "wardn", "version": "0.2.0", "extract": "discouraged",
  "restore": { "args": ["restore", "{archive}", "-i", "{identity}"], ${nix} "brew": "rayvn-central/tap/wardn" } }
MANIFEST
}

# Creates an archive of the test input with a manifest, setting the named vars to the archive and manifest paths.

newManifestArchive() {
    local -n _nmaArchiveRef=$1
    local -n _nmaManifestRef=$2
    newManifestFile _nmaManifestRef
    local outputDir; outputDir="${ makeTempDir; }"
    _nmaArchiveRef="${ newSecureArchive -C "${testInputDir}" file1.txt -i "${keyFile}" -R "${pubFile}" -n test -o "${outputDir}" \
        -m "${_nmaManifestRef}"; }" || fail "creating an archive with a manifest failed"
}

testManifestInsideEncryptionAndSigned() {
    local archive manifest; newManifestArchive archive manifest
    local outer inner; outer="${ makeTempDir; }"; inner="${ makeTempDir; }"
    tar xJf "${archive}" -C "${outer}" || fail
    [[ ! -e ${outer}/${_archiveManifestName} ]] || fail "the manifest must not be outside the encryption"
    decrypt -i "${keyFile}" -o "${inner}/decrypted.tar.xz" "${outer}/${_archiveEncryptedName}" || fail
    tar xJf "${inner}/decrypted.tar.xz" -C "${inner}" || fail
    assertEqual "${ jq -c . "${manifest}"; }" "${ jq -c 'del(.valtVersion, .archiveVersion)' "${inner}/${_archiveManifestName}"; }" \
        "the manifest given must be kept, with only the versions added"
    assertEqual "${_archiveVersion}" "${ jq -r .archiveVersion "${inner}/${_archiveManifestName}"; }"
    [[ -n ${ jq -r '.valtVersion // empty' "${inner}/${_archiveManifestName}"; } ]] || fail "the valt version must be added"
    verifyFileSignature "${keyFile}" "${inner}/${_archiveManifestName}" "${inner}/${_archiveManifestSigName}"
}

# An archive made without a manifest gets the default: a valt secure archive, with the versions it was made with

testDefaultManifest() {
    local manifest="${innerExtractDir}/${_archiveManifestName}"
    assertFile "${manifest}"
    verifyFileSignature "${keyFile}" "${manifest}" "${innerExtractDir}/${_archiveManifestSigName}"
    assertEqual 'valt secure archive' "${ jq -r .kind "${manifest}"; }"
    assertEqual 'valt' "${ jq -r .tool "${manifest}"; }"
    assertEqual "${ jq -r .valtVersion "${manifest}"; }" "${ jq -r .version "${manifest}"; }"
    assertEqual 'null' "${ jq -r .restore "${manifest}"; }" "the default manifest offers no restore"
}

testInvalidManifestRejected() {
    local bad; bad="${ makeTempDir; }/bad.json"
    echo '{ "tool": "wardn" }' > "${bad}" # no kind
    local output; output="${ ( newSecureArchive -C "${testInputDir}" file1.txt -i "${keyFile}" -R "${pubFile}" -n bad \
        -o "${ makeTempDir; }" -m "${bad}" ) 2>&1; }"
    assertContains "not a valid archive manifest" "${output}"
    echo '{ "kind": "x", "tool": "rm -rf", "restore": { "args": [] } }' > "${bad}" # not a command name
    output="${ ( newSecureArchive -C "${testInputDir}" file1.txt -i "${keyFile}" -R "${pubFile}" -n bad \
        -o "${ makeTempDir; }" -m "${bad}" ) 2>&1; }"
    assertContains "not a valid archive manifest" "${output}"
}

handlerSaysNo() { cp "$1" "${handledManifest}"; return 1; }
handlerSaysYes() { cp "$1" "${handledManifest}"; return 0; }

testManifestHandlerDecidesExtraction() {
    local archive manifest; newManifestArchive archive manifest
    declare -g handledManifest; handledManifest="${ makeTempDir; }/handled.json"
    local outputDir; outputDir="${ makeTempDir; }"
    extractSecureArchive "${archive}" -i "${keyFile}" -o "${outputDir}" --manifest-handler handlerSaysNo || fail
    assertFileDoesNotExist "${outputDir}/file1.txt"
    assertEqual "${ jq -c . "${manifest}"; }" "${ jq -c 'del(.valtVersion, .archiveVersion)' "${handledManifest}"; }" "the handler must get the manifest"
    extractSecureArchive "${archive}" -i "${keyFile}" -o "${outputDir}" --manifest-handler handlerSaysYes || fail
    assertFile "${outputDir}/file1.txt"
}

# With the default manifest, the handler is given it (here deciding not to extract), and valt decrypt extracts quietly

testDefaultManifestHandled() {
    declare -g handledManifest; handledManifest="${ makeTempDir; }/handled.json"
    local outputDir; outputDir="${ makeTempDir; }"
    extractSecureArchive "${archiveFile}" -i "${keyFile}" -o "${outputDir}" --manifest-handler handlerSaysNo || fail
    assertEqual 'valt secure archive' "${ jq -r .kind "${handledManifest}"; }"
    local output; output="${ rayvnTest_ValtKeyPassphrase="${rayvnTest_ValtKeyPassphrase}" valt decrypt "${archiveFile}" \
        -i "${keyFile}" -o "${outputDir}" 2>&1 < /dev/null; }"
    assertEqual 0 $? "decrypt must succeed: ${output}"
    assertFile "${outputDir}/file1.txt"
    [[ ${output} != *'This archive is'* ]] || fail "a plain valt archive needs no explaining: ${output}"
}

# The program installed comes first, then Nix, then Homebrew, which is not offered once the program is installed

testRestorePathways() {
    local manifest noNix; newManifestFile manifest; newManifestFile noNix no-nix
    local -a pathways
    local -x rayvnTest_ArchiveCommands
    rayvnTest_ArchiveCommands='wardn nix brew'; archiveRestorePathways "${manifest}" pathways
    assertEqual 'installed nix' "${pathways[*]}"
    rayvnTest_ArchiveCommands='nix brew'; archiveRestorePathways "${manifest}" pathways
    assertEqual 'nix brew' "${pathways[*]}"
    rayvnTest_ArchiveCommands='brew'; archiveRestorePathways "${manifest}" pathways
    assertEqual 'brew' "${pathways[*]}"
    rayvnTest_ArchiveCommands='nix'; archiveRestorePathways "${noNix}" pathways
    assertEqual '' "${pathways[*]}" "a manifest with no Nix way must not offer Nix"
    rayvnTest_ArchiveCommands=''; archiveRestorePathways "${manifest}" pathways
    assertEqual '' "${pathways[*]}"
}

testShowRestoreCommands() {
    local manifest; newManifestFile manifest
    local output; output="${ showArchiveRestoreCommands "${manifest}" backup.valt '<key>'; }"
    assertContains 'wardn restore backup.valt -i <key>' "${output}"
    assertContains 'nix run github:phoggy/wardn/v0.2.0#restore -- restore backup.valt -i <key>' "${output}"
    assertContains $'brew tap rayvn-central/tap\n    brew trust --tap rayvn-central/tap\n    brew install rayvn-central/tap/wardn' \
        "${output}" "a third-party tap is tapped and trusted before installing from it"
}

testArchiveBrewTap() {
    assertEqual 'rayvn-central/tap' "${ _archiveBrewTap rayvn-central/tap/wardn; }"
    assertEqual '' "${ _archiveBrewTap wardn; }" "a formula from Homebrew's own tap needs no tap"
}

testReadmeRestoreSection() {
    local archive manifest; newManifestArchive archive manifest
    local outer; outer="${ makeTempDir; }"
    tar xJf "${archive}" -C "${outer}" || fail
    local readme; readFile "${outer}/${_archiveReadMeName}" readme
    assertContains '▋ Restore' "${readme}"
    assertContains 'This archive is a wardn vault backup, made with wardn 0.2.0.' "${readme}"
    assertContains "nix run github:phoggy/wardn/v0.2.0#restore -- restore ${ baseName "${archive}"; } -i <private-key-file>" \
        "${readme}"
    [[ ${ cat "${outerExtractDir}/${_archiveReadMeName}"; } != *'▋ Restore'* ]] || fail "an archive without a manifest needs no Restore section"
}

# Without a terminal, valt decrypt shows how to restore rather than extracting; --extract extracts, with a warning

testDecryptCommandRestoresInsteadOfExtracting() {
    local archive manifest; newManifestArchive archive manifest
    local outputDir; outputDir="${ makeTempDir; }"
    local output; output="${ rayvnTest_ValtKeyPassphrase="${rayvnTest_ValtKeyPassphrase}" valt decrypt "${archive}" \
        -i "${keyFile}" -o "${outputDir}" 2>&1 < /dev/null; }"
    assertEqual 0 $? "decrypt must succeed: ${output}"
    output="${ stripAnsi "${output}"; }"
    assertContains 'This archive is a wardn vault backup, made with wardn 0.2.0.' "${output}"
    assertContains "restore ${archive} -i" "${output}"
    assertFileDoesNotExist "${outputDir}/file1.txt"

    output="${ rayvnTest_ValtKeyPassphrase="${rayvnTest_ValtKeyPassphrase}" valt decrypt "${archive}" -i "${keyFile}" \
        -o "${outputDir}" --extract 2>&1 < /dev/null; }"
    assertEqual 0 $? "decrypt --extract must succeed: ${output}"
    assertContains 'extracting its files as asked' "${ stripAnsi "${output}"; }"
    assertFile "${outputDir}/file1.txt"
}

rayvnTest_ModifiableFunctions=1 # testDiskTempWarns replaces makeSecureTempDir
source rayvn.up 'rayvn/test' 'valt/archive' 'valt/decrypt'
main "$@"
