#!/usr/bin/env bash

set -o noclobber -o noglob -o nounset -o pipefail
IFS=$'\n'

# If the option `use_preview_script` is set to `true`,
# then this script will be called and its output will be displayed in ranger.
# ANSI color codes are supported.
# STDOUT is read.  Exit code 0--7 is interpreted as:
# code | interpretation
# -----+---------------------------------------------
# 0    | success, display stdout
# 1    | no preview, show binary identification
# 2    | plain text, show file contents
# 3    | fix width, display stdout, then logic for code 2
# 4    | fix height, display stdout, then logic for code 2
# 5    | fix width and height, display stdout, then logic for code 2
# 6    | image, display stdout, then logic for code 2
# 7    | empty, display nothing
# 8    | terminal image, display stdout

FILE_PATH="${1}"         # Full path of the highlighted file
PV_WIDTH="${2}"          # Width of the preview pane (number of fitting characters)
PV_HEIGHT="${3}"         # Height of the preview pane (number of fitting characters)
IMAGE_CACHE_PATH="${4}"  # Full path that should be used to cache image previews
PV_IMAGE_ENABLED="${5}"  # 'True' if image previews are enabled, 'False' otherwise

extension="${FILE_PATH##*.}"
extension="$(printf "%s" "${extension}" | tr '[:upper:]' '[:lower:]')"

handle_extension() {
    case "${extension}" in
        # Archive
        a|ace|alz|arc|arj|bz|bz2|cab|cpio|deb|gz|jar|lha|lz|lzh|lzma|lzo|\
        rpm|rz|t7z|tar|tbz|tbz2|tgz|tlz|txz|tZ|tzo|war|xpi|xz|Z|zip)
            atool --list -- "${FILE_PATH}" && exit 5
            bsdtar --list --file "${FILE_PATH}" && exit 5
            exit 1;;
        rar)
            # Avoid password prompt by forcing non-interactive mode
            unrar lt -p- -- "${FILE_PATH}" && exit 5
            exit 1;;
        7z)
            # Avoid password prompt by forcing non-interactive mode
            7z l -p- -- "${FILE_PATH}" && exit 5
            exit 1;;

        # PDF
        pdf)
            # Preview as text conversion
            pdftotext -l 10 -nopgbrk -q -- "${FILE_PATH}" - | \
              fmt -w "${PV_WIDTH}" && exit 5
            mutool draw -F txt -i -- "${FILE_PATH}" 1-10 | \
              fmt -w "${PV_WIDTH}" && exit 5
            exiftool "${FILE_PATH}" && exit 5
            exit 1;;

        # BitTorrent
        torrent)
            transmission-show -- "${FILE_PATH}" && exit 5
            exit 1;;

        # HTML
        htm|html|xhtml)
            lynx -dump -- "${FILE_PATH}" && exit 5
            elinks -dump "${FILE_PATH}" && exit 5
            pandoc -s -t markdown -- "${FILE_PATH}" && exit 5
            ;;
    esac
}

handle_image() {
    local mimetype="${1}"
    case "${mimetype}" in
        # SVG
        image/svg+xml)
            convert "${FILE_PATH}" "${IMAGE_CACHE_PATH}" && exit 6
            exit 1;;

        # Image
        image/*)
            # Preview image using chafa (Requested change)
            chafa -c 256 -s "${PV_WIDTH}x${PV_HEIGHT}" "${FILE_PATH}" && exit 4
            exit 1;;
    esac
}

handle_mime() {
    local mimetype="${1}"
    case "${mimetype}" in
        # Text (Requested change: use bat with line numbers)
        text/* | */xml)
            env COLORTERM=8bit bat --color=always --style="plain,numbers" \
                --terminal-width "${PV_WIDTH}" -- "${FILE_PATH}" && exit 5
            exit 2;;

        # Image
        image/*)
            handle_image "${mimetype}"
            ;;

        # Video and audio
        video/* | audio/*)
            mediainfo "${FILE_PATH}" && exit 5
            exiftool "${FILE_PATH}" && exit 5
            exit 1;;
    esac
}

MIMETYPE="$(file --dereference --brief --mime-type -- "${FILE_PATH}")"
if [[ "${PV_IMAGE_ENABLED}" == 'True' ]]; then
    handle_image "${MIMETYPE}"
fi
handle_extension
handle_mime "${MIMETYPE}"

exit 1
