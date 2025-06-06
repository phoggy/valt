#!/usr/bin/env bash

# This file is required when creating a new public key pair and are used
# to customize the generated PDF. The PDF contains a backup of the keys
# in paper form (aka "paper key") along with usage instructions.

# The first page is in the form of a letter, where you'll have a closing line
# followed by your name as 'signature'.

closing="I hope you never need this!"
author="Bob Barker"

# In the event that you are unavailable or incapacitated when encrypted file
# content is needed, you must provide contact info for at least one person
# with appropriate computer skills (terminal command line tools) to help.
#
# This is POTENTIALLY CRITICAL information, so please give it the attention
# it deserves!

contacts=(
    "Billy Bob: +1 555-555-1212, @billy_bob1725, billy_bob@gmail.com. 14 Main Street, Small Town, AR 95466 USA"
    "Aunt Martha: +44 791 112 4456, @aunt_martha1, martha@aol.com. 221B Baker Street, London, NW1 6XE UNITED KINGDOM"
)

# Please change the following to "yes" when you have completed filling out
# the information above.

completed="no"
