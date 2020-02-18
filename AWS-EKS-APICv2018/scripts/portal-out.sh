#!/usr/bin/env bash
set -eu -o pipefail

basepath="$(dirname $0)"
. "${basepath}/envfile"

apicup subsys create portal portal --k8s
apicup subsys set portal registry ${REGISTRY}
apicup subsys set portal registry-secret dummy
apicup subsys set portal portal-admin ${ep_padmin}
apicup subsys set portal portal-www ${ep_portal}
apicup subsys set portal namespace ${NAMESPACE}
apicup subsys set portal storage-class gp2
apicup subsys set portal www-storage-size-gb 5
apicup subsys set portal backup-storage-size-gb 5
apicup subsys set portal db-storage-size-gb 12
apicup subsys set portal db-logs-storage-size-gb 2
apicup subsys set portal admin-storage-size-gb 1
apicup subsys set portal mode dev

apicup subsys install portal --out portal-out
