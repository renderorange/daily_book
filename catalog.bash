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

# check timestamp on server
echo -n 'checking timestamp on server - '
NEW_TIMESTAMP=$(curl -s gutenberg.pglaf.org/cache/epub/feeds/ | grep rdf-files.tar.bz2 | egrep -oh '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}')
if [ $? == 1 ]; then error; else echo 'done'; fi

echo -n 'comparing timestamp to current index - '
OLD_TIMESTAMP=$(stat -c %y index.txt|awk -F':' '{print $1":"$2}')
if [ $? == 1 ]; then error; else echo 'done'; fi

# DEBUG
echo "NEW: $NEW_TIMESTAMP OLD: $OLD_TIMESTAMP"
exit

# download the new archive
echo -n 'downloading new archive - '
WGET=$(wget --quiet 'gutenberg.pglaf.org/cache/epub/feeds/rdf-files.tar.bz2')
if [ $? == 1 ]; then error_and_exit; else echo 'done'; fi

# unpack
echo -n 'unpacking the archive - '
BUNZIP2=$(bunzip2 rdf-files.tar.bz2)
if [ $? == 1 ]; then error_and_exit; else echo 'done'; fi
echo -n "untar'ing - "
UNTAR=$(tar xf rdf-files.tar)
if [ $? == 1 ]; then error_and_exit; else echo 'done'; fi

# remove tar
echo -n 'removing tar - '
RM=$(rm -f rdf-files.tar)
if [ $? == 1 ]; then warn; else echo 'done'; fi

# building the index
echo -n 'building the index - '
grep txt cache/epub/*/* | egrep -v "utf-8|-" | cut -d'/' -f3 > index.txt.new
echo 'done'

# rename new to old
echo -n 'renaming new and removing the old index - '
mv index.txt.new index.txt
echo 'done'

# rock the cache-ba
echo -n 'removing the old cache - '
RM_CACHE=$(rm -rf cache)
if [ $? == 1 ]; then warn; else echo 'done'; fi

# you made it!
echo 'all done' && exit 0
