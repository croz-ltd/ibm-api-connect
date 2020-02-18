#!/usr/bin/env bash
set -eu -o pipefail

basepath="$(dirname $0)"
. "${basepath}/envfile"

apicup subsys create mgmt management --k8s
apicup subsys set mgmt namespace ${NAMESPACE}
apicup subsys set mgmt registry ${REGISTRY}
apicup subsys set mgmt registry-secret dummy
apicup subsys set mgmt platform-api   ${ep_api}
apicup subsys set mgmt api-manager-ui ${ep_apim}
apicup subsys set mgmt cloud-admin-ui ${ep_cm}
apicup subsys set mgmt consumer-api ${ep_consumer}
apicup subsys set mgmt storage-class gp2
apicup subsys set mgmt cassandra-cluster-size 1
apicup subsys set mgmt cassandra-max-memory-gb 4
apicup subsys set mgmt cassandra-volume-size-gb 5
apicup subsys set mgmt create-crd true
apicup subsys set mgmt mode dev

apicup subsys install mgmt --out mgmt-out
