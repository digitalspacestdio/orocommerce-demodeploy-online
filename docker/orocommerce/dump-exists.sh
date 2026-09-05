#!/bin/bash
# Exit 0 when a dump named $1 is present under the dumps directory.
DUMPS_DIR="${ORO_DUMPS_DIR:-/dumps}"
[[ -f "$DUMPS_DIR/${1:-demo}/db.sql.gz" ]]
