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
    testPublicReadmeNoNotes
    testPublicReadmeWithNotes
    testPrivateReadmeStructure
    testPrivateReadmeNoNotes
    testPrivateReadmeWithNotes

    # Options
    testForceOverwrite
    testNoForceFailsOnConflict
    testCustomName
    testCustomOutputDir

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
    skipReadPasswordCheck=1

    declare -g pubFile keyFile testInputDir archiveOutputDir archiveFile archivePubFile
    declare -g outerExtractDir innerExtractDir payloadExtractDir

    local testKeyDir; testKeyDir="${ makeTempDir; }"
    newValtKeys 'test' "${testKeyDir}" pubFile keyFile

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
    ( verifySecureArchive "${tamperedArchive}" -i "${keyFile}" ) 2>/dev/null \
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
    ( verifySecureArchive "${tamperedArchive}" -i "${keyFile}" ) 2>/dev/null \
        && fail "must fail when payload is tampered"
    return 0
}

testVerifyMissingArchiveFails() {
    ( verifySecureArchive "/nonexistent/path.valt" -i "${keyFile}" ) 2>/dev/null \
        && fail "must fail with nonexistent archive"
    return 0
}

testVerifyMissingIdentityFails() {
    ( verifySecureArchive "${archiveFile}" ) 2>/dev/null \
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

testForceOverwrite() {
    local outputDir; outputDir="${ makeTempDir; }"
    local ts; ts="${ timeStamp UTC; }"
    touch "${outputDir}/overwrite-${ts}.valt" "${outputDir}/overwrite-${ts}.valt.pub"
    local file; file="${ newSecureArchive -C "${testInputDir}" file1.txt \
        -i "${keyFile}" -R "${pubFile}" -n overwrite -z UTC -o "${outputDir}" --force; }"
    assertFile "${file}"
}

testNoForceFailsOnConflict() {
    local outputDir; outputDir="${ makeTempDir; }"
    local ts; ts="${ timeStamp UTC; }"
    touch "${outputDir}/conflict-${ts}.valt"
    ( newSecureArchive -C "${testInputDir}" file1.txt \
        -i "${keyFile}" -R "${pubFile}" -n conflict -z UTC -o "${outputDir}" ) 2>/dev/null \
        && fail "must fail when archive already exists"
    return 0
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

source rayvn.up 'rayvn/test' 'valt/archive' 'valt/decrypt'
main "$@"
