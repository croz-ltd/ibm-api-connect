# How to install APIC v2018 in AWS EKS environment

So you need to prepare the important
[IBM API Connect (APIC)](https://www.ibm.com/support/knowledgecenter/SSMNED_2018/mapfiles/getting_started.html)
demo for your client? You would like to show all the features and possibilities
which APIC provides and would like to set up the APIC demo environment in no
time?

I guess this environment would need to be available on the Internet so demo APIs
can be called by your clients during your presentation. These APIs should also
be able to access the Internet so they can call any publicly available REST or
SOAP services your client could ask you to use for the demo purposes.

While such setup can take quite a lot of your time and effort, this article will
show you how to do it as easily as possible within constrained time limits.

## Local machine prerequisites

- aws cli (v1, maybe v2 could work)
  - https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html
- helm (v2, apicup doesn't work with helm v3)
  - https://github.com/helm/helm/releases
- kubectl
  - https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html
- eksctl
  - https://docs.aws.amazon.com/eks/latest/userguide/getting-started-eksctl.html
- docker

Versions used on machine for this setup:

```
$ aws --version
aws-cli/1.17.5 Python/2.7.12 Linux/4.15.0-65-generic botocore/1.14.5

$ helm version
Client: &version.Version{SemVer:"v2.16.1", GitCommit:"bbdfe5e7803a12bbdf97e94cd847859890cf4050", GitTreeState:"clean"}
Server: &version.Version{SemVer:"v2.16.1", GitCommit:"bbdfe5e7803a12bbdf97e94cd847859890cf4050", GitTreeState:"clean"}

$ kubectl version
Client Version: version.Info{Major:"1", Minor:"14+", GitVersion:"v1.14.7-eks-1861c5", GitCommit:"1861c597586f84f1498a9f2151c78d8a6bf47814", GitTreeState:"clean", BuildDate:"2019-09-24T22:12:08Z", GoVersion:"go1.12.9", Compiler:"gc", Platform:"linux/amd64"}
Server Version: version.Info{Major:"1", Minor:"14+", GitVersion:"v1.14.9-eks-c0eccc", GitCommit:"c0eccca51d7500bb03b2f163dd8d534ffeb2f7a2", GitTreeState:"clean", BuildDate:"2019-12-22T23:14:11Z", GoVersion:"go1.12.12", Compiler:"gc", Platform:"linux/amd64"}

$ eksctl version
[ℹ]  version.Info{BuiltAt:"", GitCommit:"", GitTag:"0.12.0"}

$ docker --version
Docker version 19.03.5, build 633a0ea838
```


## Running scripts

If you want to use scripts here to setup your APIC v2018 in EKS:
- prepare all required cli applications, and login to all environments you wish
  to use (docker, aws)
- prepare [envfile](./scripts/envfile) with proper values
- cd to this directory
- run the script [install-apic-in-new-eks.sh](./install-apic-in-new-eks.sh)

After initial installation you should be able to login to Cloud Manager using
default username/password combination (admin/7iron-hide). Strating from there
you can make initial configuration by hand (or you can even script that).

## Installation overview

Here is overview of complete installation where initial installation is done
using script while initial configuration is done using web admin apic
applications.

### EKS worker nodes selection

- t3a.2xlarge
  - ok
- t3a.xlarge
  - not enough CPUs :(

EU (Ireland)

| Name        | vCPU | Memory (GiB) | Linux/UNIX Usage |
| ----------- | ---- | ------------ | ---------------- |
| t3a.xlarge  | 4    | 16 GiB       | $0.1632 per Hour |
| t3a.2xlarge | 8    | 32 GiB       | $0.3264 per Hour |

### EKS with managed nodes and eksctl

In its first release, EKS provided managed Kubernetes control plane but the only
way to use it was to manually add worker nodes to the cluster (EC2 instances
created "by hand"). Fortunately, Amazon didn't stop there and
[later provided managed node groups](https://aws.amazon.com/blogs/containers/eks-managed-node-groups/)
which makes EKS setup much easier. Even better than that, you don't have to use
CloudFormation for this setup directly, there is a command-line tool (eksctl)
which makes setup of EKS fast and easy (scripting anyone?).

All you have to do to start a new EKS Cluster is one command execution,
something like:
```bash
eksctl create cluster \
--name CLUSTER_NAME \
--version 1.14 \
--region AWS_REGION \
--nodegroup-name standard-workers \
--node-type t3a.2xlarge \
--nodes CLUSTER_NODES_NO \
--nodes-min CLUSTER_NODES_NO \
--nodes-max CLUSTER_NODES_NO \
--ssh-access \
--ssh-public-key PATH_TO_SSH_PUBLIC_KEY \
--managed
```

You need to provide the following parameters to this command:
- CLUSTER_NAME: name of you cluster
- AWS_REGION: AWS region your cluster will be deployed to
- CLUSTER_NODES_NO: number of nodes in a cluster
  - APIC 2018.4.1.9 can be successfully installed using only one t3a.2xlarge
    node though its resources (8 vCPU / 32 GiB Memory) are not satisfying the
    minimum resource recommendations by IBM - don't use such setup for anything
    other than testing. If you add 2 such nodes resources would be more than
    enough, though for HA you would want to have 3 nodes
- PATH_TO_SSH_PUBLIC_KEY: a path to public SSH key - it's private part will be
  used to connect to all nodes in cluster

From the test setup trials we made, it seems that the cheapest EC2 instance you
can use for APIC worker nodes is t3a.2xlarge - with less than 8 vCPU and 32 GiB
memory nodes APIC installation will not work.

### EKS nodes setup

After running the "eksctl create cluster" command and waiting for some time, the
EKS cluster will be created and you can get a public DNS name for each node. You
need that information (+ ssh private key) to connect to each node and increase
max virtual memory parameter - otherwise, APIC won't successfully start because
of [Elasticsearch requirements](https://www.elastic.co/guide/en/elasticsearch/reference/current/vm-max-map-count.html).

As you probably know, you won't be able to configure APIC if it doesn't have a
proper email server configuration. There are activation emails you need to
receive to properly setup APIM and Developer Portals. For test purposes, you
don't have to use a fully-fledged SMTP service (for example AWS SES) but can get
away with any kind of [test SMTP service such as a MailHog](https://github.com/mailhog/MailHog).
Simply start your test SMTP server on one of the EC2 instances and use instance
hostname later in APIC email server configuration.

### k8s dashboard installation

After the initial EKS cluster setup, you will probably want to have a better
insight into your Kubernetes (k8s) cluster. That is why you should probably install
[k8s dashboard](https://github.com/kubernetes/dashboard)> (and
[metrics server](https://github.com/kubernetes-sigs/metrics-server) as it's
prerequisite). Installation is quite straight forward and you don't have to
expose it to the world, you can just use `kubectl proxy` to access it for your
administrative needs.

### nginx-ingress installation

You will need to access your installation from the Internet and that is where
nginx-ingress comes into the picture. Properly installed helm is needed for this
(helm v2 will be required by APIC installation latter, apicup command,
  unfortunately, won't work with helm v3) but other than that deployment is
  quite straight-forward. After deployment, AWS will give you ingress DNS name
  available on the Internet. Ingress DNS name will resolve to as many IP
  addresses as many (managed) worker nodes you have configured (DNS will load
    balance traffic between ingress controller pods).

You could configure DNS under your control to properly resolve your nice and
shiny domain name (something like "myclientdemo.mycompany.com") to ingress DNS
name (something less memorable like "a7...a8.elb.region.amazonaws.com"). Or you
could just use any wildcard DNS, for example [nip.io](https://nip.io/) and use
only 1 of IP addresses to which ingress DNS name resolves. Be warned though that
you should wait for some time before getting proper IP address(es) for ingress
DNS name - you need to wait a bit after deployment for DNS to propagate properly
before you get "settled" IP addresses.

For example if you use nip.ip, for the following nslookup result:
```bash
$ nslookup a7..a8.elb.eu-west-1.amazonaws.com
Server:		127.0.1.1
Address:	127.0.1.1#53

Non-authoritative answer:
Name:	a7..a8.elb.region.amazonaws.com
Address: 52.1.2.3
Name:	a7..a8.elb.region.amazonaws.com
Address: 18.1.2.3
```
...you could use either one of following DNS name sets to configure your APIC
endpoints:
```bash
*.52.1.2.3.nip.ip
*.18.1.2.3.nip.ip
```

### APIC docker images upload

When using ECR in AWS you have to create one repository for each docker image
you will push to ECR. For example, for DataPower image
"ibmcom/datapower:2018.4.1.9.315826-nonprod" you will have to create an ECR
repository named "datapower".

For DataPower and DataPower monitor a process of uploading consists of 4 steps
(registry="5...0.dkr.ecr.region.amazonaws.com"):
- create aws repository ($registry/repository_name)
- docker load image
- docker tag image (for AWS repozitory)
- docker push

For management, analytics and portal docker images apicup command-line tools
help you to push proper images to AWS ECR. This makes a process of pushing all
images in each APIC k8s archive much easier.
The version of an apicup tool determines which version of APIC are you
installing so make sure the apicup version you are using is the same as a
version of downloaded APIC docker image archives.

### APIC installation using apicup comand line tool

If the configuration is done right and all previous steps are executed APIC
installation should be quite easy using IBM's apicup command-line tool. Once per
installation, you have to do the following steps:
- Create a Kubernetes namespace
- Create a local empty installation directory for apicup
- Init installation directory using apicup

Once per each subsystem (management, gateway, analytics &amp; developer portal),
you have to do the following steps:
- Prepare all resources for subsystem
- Install subsystem into Kubernetes

### APIC initial configuration

After APIC installation, you should get usable but empty  IBM API Connect 2018
environment. You will have to do some additional configuration steps (probably
  by administrative web applications though this should not be a problem to
  convert this to another script if REST administrative interface is used).

Initial configuration should apply the following steps:
- Cloud manager
  - Configure email server
  - Register DataPower Service (Topology)
  - Register Analytics Service (Topology)
  - Register Portal service (Topology)
  - Associate Analytics Service to DataPower Service (Topology)
  - Create Provider Organization
- API manager
  - Configure Gateway Service (Catalog)
  - Create Portal (Catalog)
  - Create or import demo product(s) &amp; API(s)
  - Publish a demo product(s) to catalog
- Developer Portal
  - Create &amp; activate a new user account
  - Create demo client application
  - Subscribe demo client application to a product
  - Test API calls
