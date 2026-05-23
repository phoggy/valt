#!/usr/bin/env bash

main() {
    init "$@"

    testEncryptFileWithPublicKey
    testEncryptFileWithRecipient
    testEncryptStdin
    testEncryptWithArmor
    testEncryptDirectory
    testEncryptVar
    testEncryptNonExistentPathFails

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
    declare -g testKeyDir pubFile keyFile ageRecipient testText testFile
    testKeyDir="${ makeTempDir; }"
    createValtKeys 'test' "${testKeyDir}" pubFile keyFile
    ageRecipient="${ recipient "${pubFile}"; }"
    testText='The quick brown fox jumps over the lazy dog.'
    testFile="${ makeTempFile test.txt; }"
    echo "${testText}" > "${testFile}"
}

testEncryptFileWithPublicKey() {
    local outFile; outFile="${ makeTempFile; }"
    encrypt "${testFile}" -R "${pubFile}" -o "${outFile}"
    assertTrue "encrypted file must be non-empty" test -s "${outFile}"
    assertFalse "encrypted file should not contain plaintext" grep -qF "${testText}" "${outFile}"
}

testEncryptFileWithRecipient() {
    local outFile; outFile="${ makeTempFile; }"
    encrypt "${testFile}" -r "${ageRecipient}" -o "${outFile}"
    assertTrue "encrypted file must be non-empty" test -s "${outFile}"
}

testEncryptStdin() {
    local outFile; outFile="${ makeTempFile; }"
    echo "${testText}" | encrypt -R "${pubFile}" -o "${outFile}"
    assertTrue "encrypted output must be non-empty" test -s "${outFile}"
}

testEncryptWithArmor() {
    local outFile; outFile="${ makeTempFile; }"
    encrypt "${testFile}" -R "${pubFile}" --armor -o "${outFile}"
    assertTrue "armored file must be non-empty" test -s "${outFile}"
    local armored; readFile "${outFile}" armored
    assertContains '-----BEGIN AGE ENCRYPTED FILE-----' "${armored}"
    assertContains '-----END AGE ENCRYPTED FILE-----' "${armored}"
}

testEncryptDirectory() {
    local testDir; testDir="${ makeTempDir; }"
    echo 'hello' > "${testDir}/hello.txt"
    local outFile; outFile="${ makeTempFile dir.age; }"
    encrypt "${testDir}" -R "${pubFile}" -o "${outFile}"
    local tarFile; tarFile="${ makeTempFile dir.tar.xz; }"
    decrypt -i "${keyFile}" "${outFile}" -o "${tarFile}"
    local contents; contents="${ tar tf "${tarFile}"; }" || fail "tar listing failed"
    local dirName; dirName="${ baseName "${testDir}"; }"
    grep -qxF "${dirName}/hello.txt" <<< "${contents}" || fail "tar entry must be relative: '${dirName}/hello.txt' not found"
}

testEncryptVar() {
    local secret='s3cr3t v@lue'
    local encFile; encFile="${ makeTempFile; }"
    encrypt -v secret -R "${pubFile}" -o "${encFile}"
    assertTrue "encrypted var output must be non-empty" test -s "${encFile}"
    local result
    result="${ decrypt -i "${keyFile}" "${encFile}"; }"
    assertEqual "${secret}" "${result}"
}

testEncryptNonExistentPathFails() {
    ( encrypt '/no/such/path' -R "${pubFile}" ) 2> /dev/null && fail "non-existent path must fail"
    return 0
}

source rayvn.up 'rayvn/test' 'valt/keys'
main "$@"
