#!/bin/bash

# Copyright (C) 2016  Atomic Jolt
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, either version 3 of the License, or (at your option) any
# later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program.  If not, see <http://www.gnu.org/licenses/>.

# This software is based on the previous work of David Owen <dsowen@fugue88.ws>.
# See
# <http://blog.fugue88.ws/archives/2011-04/Perceived-shortcomings-of-style-checkers-and-a-potential-solution>.

set -eu
shopt -s extglob

function decorate {
    local last_file=""
    local sed_file=""

    while read -r
    do
        local file=${REPLY%%:+([0-9]):+([0-9]): ?: *}
        local rest=${REPLY#"$file":}
        local line=${rest%%:*}
        local msg=${rest#+([0-9]):+([0-9]): }

        file=$(realpath --relative-to=. "$file")

        if [ "$file" != "$last_file" ]
        then
            if [ -n "$sed_file" ]
            then
                sed -f "$sed_file" -ri "$last_file"
                rm "$sed_file"
            fi
            sed_file=$(mktemp --tmpdir tmp-dstyle.XXX)
            echo "# $file" >> "$sed_file"
            last_file="$file"
        fi

        echo "${line}s/$/#dstyle:$(echo "$file:$line:$msg" | sed -r 's:/:\\/:g')/" >> "$sed_file"
    done

    sed -f "$sed_file" -ri "$last_file"
    rm "$sed_file"
}



REPO=$(pwd)
LEFT=$(mktemp -d --tmpdir tmp-dstyle-left-dir.XXX)
RIGHT=$(mktemp -d --tmpdir tmp-dstyle-right-dir.XXX)
LEFT_OUT=$(mktemp --tmpdir tmp-dstyle-left-out.XXX)
RIGHT_OUT=$(mktemp --tmpdir tmp-dstyle-left-out.XXX)

function clean {
    rm -rf "$LEFT" "$LEFT_OUT" "$RIGHT" "$RIGHT_OUT"
}

trap clean EXIT



git archive --format=tar master | tar -x -C "$LEFT"
cd "$LEFT"
rm -rf .git
rubocop -f e -o "$LEFT_OUT" || true
decorate < "$LEFT_OUT"

cd "$RIGHT"
tar -c -C "$REPO" . | tar -x
rm -rf .git
rubocop -f e -o "$RIGHT_OUT" || true
decorate < "$RIGHT_OUT"

cd "$REPO"
diff -ru "$LEFT" "$RIGHT" | egrep '^[+]' | egrep -o '#dstyle:.*' | sed -r 's/^#dstyle://
s/#dstyle:/\n/g'
