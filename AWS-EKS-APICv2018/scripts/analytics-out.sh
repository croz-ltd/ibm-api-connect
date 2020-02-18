#!/usr/bin/env bash
set -eu -o pipefail

basepath="$(dirname $0)"
. "${basepath}/envfile"

apicup subsys create analytics analytics --k8s
apicup subsys set analytics namespace ${NAMESPACE}
apicup subsys set analytics registry ${REGISTRY}
apicup subsys set analytics registry-secret dummy
apicup subsys set analytics analytics-ingestion ${ep_ai}
apicup subsys set analytics analytics-client ${ep_ac}
apicup subsys set analytics coordinating-max-memory-gb 6
apicup subsys set analytics data-max-memory-gb 8
apicup subsys set analytics data-storage-size-gb 200
apicup subsys set analytics master-max-memory-gb 6
apicup subsys set analytics master-storage-size-gb 5
apicup subsys set analytics storage-class gp2
apicup subsys set analytics mode dev
apicup subsys install analytics --out analytics-out
