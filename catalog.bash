#!/bin/bash

# catalog.bash
# download and process the catalog files from gutenberg.org's pglaf mirror


# functions
function error_and_exit {
    echo 'error' && exit 1
}

function warn {
    echo 'error'
}

# download the new archive
wget 'gutenberg.pglaf.org/cache/epub/feeds/rdf-files.tar.bz2' || error_and_exit

# unpack
bunzip2 rdf-files.tar.bz2 || error_and_exit
tar xvf rdf-files.tar || error_and_exit

# remove tar
rm -f rdf-files.tar || warn

# gather the names
grep txt cache/epub/*/* | egrep -v "utf-8|-" | cut -d'/' -f3 > index.txt.new

# rename new to old
mv index.txt.new index.txt

# rock the cache-ba
rm -rf cache || warn

# you made it!
echo 'all done' && exit 0
