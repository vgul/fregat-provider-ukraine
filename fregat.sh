#!/bin/bash

set -u

EFFSCRIPT="$(readlink -f "${BASH_SOURCE[0]}")"
MY_DIR="$(dirname "${EFFSCRIPT}")"

CREDENTIALS="${MY_DIR}/fregat.credentials"
if [ -f "${CREDENTIALS}" ]; then
    source "${CREDENTIALS}"

    # something like user-1234567
    echo "${LOGIN}"    > /dev/null

    # something like any8
    echo "${PASSWORD}" > /dev/null

    ## user-specific sub-url
    # "?&id=123456&int_id=123456&a=987&act=seance}"
    echo "${SESSIONS_PARAMS}" > /dev/null

else
    echo "Credentials file '${CREDENTIALS}' not found."
    exit 1
fi

## Standard fregat entry poing for restricted area
FREGAT_URL=https://info.fregat.net/cgi-bin/stat.pl

# user-agent; can be additionally specified in fregat.credentials
UA="${UA:-Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/32.0.1700.107 Safari/537.36}" 

ROTATE_SIZE=${ROTATE_SIZE:-8}

DATA_DIR="${MY_DIR}/Data"
[ ! -d "${DATA_DIR}" ] && { mkdir ${DATA_DIR} ;}


function rotate () {
    local FILE="$1"
    local MAX=${2:-90}

    local BODY="$(basename $FILE)"
    local DATA_DIR="$(dirname $FILE)"

    local ROTATE_FLAG=
    [ -e "${FILE}" ] && ROTATE_FLAG=1

    [ -n "${ROTATE_FLAG}" ] && {
      find "${DATA_DIR}" -maxdepth 1 -name ${BODY}\.\* \( -type d -or -type f \) -printf '%f\n' | sort -t '.' -k1 -nr | while read CF; do
        NUM=${CF##*\.}
        #NUM=$(echo ${NUM}|sed -e 's/^0*//g')
        #echo "Found: $CF NUM: $NUM" >&2
        printf -v NEWCF "${BODY}.%d" $((++NUM))
        if ((NUM<=MAX)); then
            [ -d "${DATA_DIR}/${NEWCF}" ] && {
                rm -rf "${DATA_DIR}/${NEWCF}"
            }
          mv "${DATA_DIR}/$CF" "${DATA_DIR}/${NEWCF}"
        else
          [ -e "${DATA_DIR}/$NEWCF" ] && rm -rf "${DATA_DIR}/${NEWCF}"
        fi
      done
      mv "${DATA_DIR}/$BODY"  "${DATA_DIR}/${BODY}.0"
    }
}


INVOKE_DIR="${DATA_DIR}/invoke"
rotate "${INVOKE_DIR}" ${ROTATE_SIZE}
mkdir "${INVOKE_DIR}"



function get_data {
    local TAG="$1"
    local URL="$2"
    local PARAMS="${3:-}"

    local INVOKE_DATA_DIR="${INVOKE_DIR}"

    local DUMP_HEADER="${INVOKE_DATA_DIR}/${TAG}.headers"
    local DUMP_STDERR="${INVOKE_DATA_DIR}/${TAG}.stderr"
    local OUTPUT="${INVOKE_DATA_DIR}/${TAG}.output.html"

    local COOKIES_FILE="${INVOKE_DATA_DIR}/cookies.txt"
    local GET_COOKIES=
    local SET_COOKIES=
    if [ -f "${COOKIES_FILE}" ]; then
        GET_COOKIES="--cookie     ${COOKIES_FILE}"
    else
        SET_COOKIES="--cookie-jar ${COOKIES_FILE}"
    fi

    echo "${URL}" > ${INVOKE_DATA_DIR}/${TAG}.url


    CURL_CMD="curl \
                    --silent \
                    --verbose \
                    --dump-header ${DUMP_HEADER} \
                    --stderr ${DUMP_STDERR} \
                    --output ${OUTPUT} \
                    ${UA:+ --user-agent \"${UA}\"} \
                    ${PARAMS:+ --data \"${PARAMS}\"} \
                    ${SET_COOKIES:-} \
                    ${GET_COOKIES:-} \
                    ${REFERER:+--referer ${REFERER}} \
                \"${URL}\""

    eval "${CURL_CMD}"

    echo "${OUTPUT}"
}


get_data "login" "${FREGAT_URL}" "uu=${LOGIN}&pp=${PASSWORD}&submit=SUBMIT" > /dev/null
sleep 1


SESSIONS_PAGE_FILE="$(get_data "info"  "${FREGAT_URL}${SESSIONS_PARAMS}")"

DATA="$(cat "${SESSIONS_PAGE_FILE}" | elinks --dump)"

SESSIONS_INFO="$(echo "${DATA}" | grep -B 2  -A 1000 "Начало")"

echo "${SESSIONS_INFO}" | grep -P '(^\s+\d\d\.\d)|(ктив)|(\s\d\d:\d\d\s)' | sed -e 's/^\s\+//' | awk '{printf "%12s      %10s      %12s %10s    %27s\n",$1,$2,$3,$4,$5}'
