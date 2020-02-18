#!/usr/bin/env bash
set -eu -o pipefail

basepath="$(dirname $0)"
. "${basepath}/envfile"

apicup subsys create gw gateway --k8s
apicup subsys set gw api-gateway ${ep_gw}
apicup subsys set gw apic-gw-service ${ep_gwd}
apicup subsys set gw namespace ${NAMESPACE}
apicup subsys set gw max-cpu 4
apicup subsys set gw max-memory-gb 8
apicup subsys set gw storage-class gp2
apicup subsys set gw replica-count 1
apicup subsys set gw v5-compatibility-mode false
apicup subsys set gw enable-high-performance-peering true
apicup subsys set gw enable-tms true
apicup subsys set gw mode dev
apicup subsys set gw extra-values-file ${basepath}/yaml/gw-extra-values.yaml
apicup subsys set gw image-repository ${REGISTRY}/datapower
apicup subsys set gw image-tag ${apic_idg_tag}
apicup subsys set gw registry-secret dummy

apicup subsys set gw monitor-image-repository ${REGISTRY}/k8s-datapower-monitor
apicup subsys set gw monitor-image-tag ${apic_dpm_tag}

apicup subsys install gw --out gw-out
