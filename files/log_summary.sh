#!/bin/sh

# External utilities
BIN_GREP=$(command -v grep)
BIN_PERL=$(command -v perl)
BIN_WC=$(command -v wc)

# Arguments
LOG_TYPE=$1
LOG_FILE=$2

#==== Parse Backup ============================================================ 
# Output
# - Number of files backed up
# - Start time
# - End time
# - Execution time
# - Revision
#
parse_backup() {
  PACKED_FILE_COUNT=$("${BIN_GREP}" PACK_END "${LOG_FILE}" | "${BIN_WC}" -l)
  REVISION=$("${BIN_PERL}" -ne \
    'print "$1\n" if /BACKUP_END[\/_ .[:alnum:]]+ revision ([0-9]+) completed$/' \
    "${LOG_FILE}")
  START_TIME=$("${BIN_PERL}" -ne \
    'print "$1\n" if /^([0-9- :.]+) INFO BACKUP_START/' \
    "${LOG_FILE}")
  END_TIME=$("${BIN_PERL}" -ne \
    'print "$1\n" if /^([0-9- :.]+) INFO BACKUP_END/' \
    "${LOG_FILE}")

  echo "Revision ${REVISION} complete
  Start         : ${START_TIME}
  End           : ${END_TIME}
  Packed Files  : ${PACKED_FILE_COUNT}"
}


#==== Parse Prune ============================================================= 
# Output 
# - Number of fossils collected
# - Number of chunks deleted
# - Number of snapshots deleted
#
parse_prune() {
  CHUNKS_DELETED=$("${BIN_PERL}" -ne \
    'print "$1\n" if /CHUNK_DELETE.* ([a-z0-9-]+) has been permanently removed$/' \
    "${LOG_FILE}" | "${BIN_WC}" -l)
  SNAPSHOTS_DELETED=$("${BIN_PERL}" -ne \
    'print "$1\n" if /SNAPSHOT_DELETE[\/_ .[:alnum:]]+ revision ([0-9]+) has been removed$/' \
    "${LOG_FILE}" | "${BIN_WC}" -l)

  echo "Prune Complete
  Chunks Deleted    : ${CHUNKS_DELETED}
  Snapshots Deleted : ${SNAPSHOTS_DELETED}"
}

if [ ! -f "${LOG_FILE}" ]; then
  echo "Log Parse: Invaild file ${LOG_FILE}!"
  exit
fi

case "${LOG_TYPE}" in
  "PRUNE")
    parse_prune
    ;;
  "BACKUP")
    parse_backup
    ;;
esac
