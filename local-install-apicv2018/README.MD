# Installing IBM API Connect v2018.x Into Single Virtual Machine

## TL;DR 

Install procedure in a nutshell

 - Copy API Connect installation files into local-install-apicv2018/apic folder
 - `cd local-install-apicv2018`
 - `vagrant up`
 - `vagrant ssh`
 - `cd /vagrant/scripts`
 - `make loadGW`
 - `make prep`
 - `make work`

Links

 - CMC: https://cloud.10.0.0.100.nip.io
 - APIM: https://manager.10.0.0.100.nip.io/
 - Portal: https://portal.10.0.0.100.nip.io/
 - Dashboard: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/
 - DP GUI: https://10.0.0.100:9090/

## Provisioning the Machine

Vagrant is used as a mechanism to provision new VM.
You should run `vagrant up`.

This will bring new VM with IP `10.0.0.100`.

To use it you can ssh using `vagrant ssh`.

Machine should already have Docker, Kubernetes and Helm installed.

## Installing API Connect v2018.x

To install API connect put installation files in the [./apic](./apic) folder (make one).

In the [scripts](./scripts) folder is Makefile.

Initial step is to load DataPower images as they don't use `apicup` tool with `make loadGW`. 
You can execute `make all` or you can run task in phases (`make prep` and `make work` is recommended though).

## Setup kubectl on Windows

```bash
curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.15.9/bin/windows/amd64/kubectl.exe
```

Copy remote config file locally

```bash
$ mkdir -p ~/.kube && scp vagrant@10.0.0.100:/home/vagrant/.kube/config ~/.kube/config
The authenticity of host '10.0.0.100 (10.0.0.100)' can't be established.
ECDSA key fingerprint is SHA256:1Z76nTl7aEpVhcnFIanMDmBiVXrhL9SXkGVxN7LcLD0.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added '10.0.0.100' (ECDSA) to the list of known hosts.
vagrant@10.0.0.100's password:
config                                                                                100% 5449   856.5KB/s   00:00
```

Now `kubectl get nodes` should return apic node. 