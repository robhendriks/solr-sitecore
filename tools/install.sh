#!/bin/bash

help() {
    echo "usage: install --version <version> --hostname <hostname> --certificate <certificate>"
    exit 2
}

main() {
    while [ $# -gt 0 ]; do
        case $1 in
        --version)
            SOLR_VERSION=$2
            ;;
        --hostname)
            SOLR_HOSTNAME=$2
            ;;
        --certificate)
            SOLR_CERTIFICATE=$2
            ;;
        esac
        shift
    done

    if [[ -z "$SOLR_VERSION" || -z "$SOLR_HOSTNAME" || -z "$SOLR_CERTIFICATE" ]]; then
        help
    fi

    echo "SOLR_VERSION: $SOLR_VERSION"
    echo "SOLR_HOSTNAME: $SOLR_HOSTNAME"
}

main "$@"
