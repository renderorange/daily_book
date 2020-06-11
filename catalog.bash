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

# force re-download of catalog
echo -n 'removing old catalog - '
CAT_RM=$(rm -f catalog.txt)
if [ $? == 1 ]; then warn; else echo 'done'; fi

MIRROR_URL='gutenberg.readingroo.ms/cache/generated/feeds'

# compared the timestamps
if [ -f catalog.txt ]; then  # first check if the catalog exists locally, otherwise just download it
    echo -n 'checking timestamp on server - '
    NEW_TIMESTAMP=$(curl -s $MIRROR_URL | grep rdf-files.tar.bz2 | egrep -oh '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}')
    if [ $? == 1 ]; then error_and_exit; else echo 'done'; fi  # exit here if there was an issue connecting

    echo -n 'checking timestamp on stored catalog - '
    OLD_TIMESTAMP=$(stat -c %y catalog.txt|awk -F':' '{print $1":"$2}')
    if [ $? == 1 ]; then warn; else echo 'done'; fi

    echo -n 'comparing timestamps - '  # admittedly, this loses about 30 seconds of accuracy in testing
    NEW_EPOCH=$(date -d "$NEW_TIMESTAMP" +%s)  # but the margin of error wasn't enough to pose an issue
    OLD_EPOCH=$(date -d "$OLD_TIMESTAMP" +%s)  # although possiblity of closeness is still there

    if [ $NEW_EPOCH -lt $OLD_EPOCH ]; then
        echo "up to date" && exit 1
    else
        echo "done"
    fi
fi

# download the new archive
echo -n 'downloading new archive - '
WGET=$(wget --quiet "$MIRROR_URL/rdf-files.tar.bz2")
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

# building the catalog
echo -n 'building the catalog - '
grep -r txt cache/epub/ | egrep -v "utf-8|-" | cut -d'/' -f3 > catalog.txt.new
echo 'done'

# rename new to old
echo -n 'renaming new and removing the old catalog - '
mv catalog.txt.new catalog.txt
echo 'done'

# rock the cache-ba
echo -n 'removing the old cache - '
RM_CACHE=$(rm -rf cache)
if [ $? == 1 ]; then warn; else echo 'done'; fi

# add the new catalog to the repo and push
echo -n 'adding new catalog to git - '
GIT_ADD=$(git add catalog.txt)
if [ $? == 1 ]; then error_and_exit; else echo 'done'; fi

echo -n 'committing - '
GIT_COMMIT=$(git commit -m 'added new catalog')
if [ $? == 1 ]; then error_and_exit; else echo 'done'; fi

echo 'pushing to remote'
GIT_PUSH=$(git push)
if [ $? == 1 ]; then error_and_exit; else echo 'done'; fi

# you made it!
echo 'all done' && exit 0

