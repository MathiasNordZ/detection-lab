# Detection Lab

A disposable purple-team lab on OpenStack. OpenTofu provisions an isolated tenant network and three Ubuntu instances; Ansible configures the blue and red tools and enrolls the target.

## Included

- **Blue:** Wazuh all-in-one (agent, manager, indexer, dashboard) and DFIR-IRIS for alert triage and case work.
- **Red:** MITRE Caldera with its stockpile plugin, plus the Atomic Red Team test library.
- **Target:** Ubuntu endpoint enrolled in Wazuh. The target has no floating IP.
- **Infrastructure:** OpenTofu/OpenStack, Ansible, and a helper script for deploy, configure, and destroy.

This is a learning lab, not a production SOC. It is sized for a small number of endpoints and uses a single-node Wazuh stack. Keep the lab isolated and run only controlled exercises against the lab target.

## Quick start

Requirements: OpenTofu 1.8+, Ansible, OpenStack CLI credentials in `clouds.yaml`, and an SSH keypair already uploaded to the OpenStack project. The OpenStack project must allow networks, routers, floating IPs, and compute instances.

1. Copy `infra/terraform.tfvars.example` to `infra/terraform.tfvars` and set the image, flavor, external network, keypair, and your public IP CIDR.
2. Set `OS_CLOUD` to your cloud name, or configure the OpenStack provider credentials as environment variables. Never put cloud passwords in this repository.
3. Run:

   ```sh
   ./lab up
   ```

   This runs `tofu apply`, writes a temporary Ansible inventory, and configures the VMs. First boot downloads container images and can take several minutes.
4. Open the printed dashboard URLs. SSH to the target through the SOC host with `ssh -J ubuntu@<soc-ip> ubuntu@<target-ip>`.
5. Tear down all OpenStack resources with `./lab destroy`.

Use `./lab plan` to review the OpenTofu changes without applying them. `./lab configure` reruns Ansible after infrastructure is up.

## Sizing

The defaults request 8 vCPU / 16 GiB / 100 GiB for SOC, 2 vCPU / 4 GiB for the attacker, and 2 vCPU / 4 GiB for the target. Wazuh's official single-node Docker deployment calls for at least 4 CPU cores, 8 GiB RAM, and 50 GiB disk; IRIS and Caldera add load. Increase the SOC flavor and volume if the OpenStack project has capacity. Images and flavors are cloud-specific and are deliberately not guessed.

## Network and access

The lab uses a private subnet behind a tenant router. The SOC and attacker receive floating IPs so you can reach the blue dashboards and Caldera; the target has no floating IP. Security group rules permit SSH and the web interfaces only from `trusted_cidr`; internal lab traffic is allowed between the three instances so agents and Caldera can communicate. Set `trusted_cidr` to a single administrator IP in CIDR form (for example `198.51.100.7/32`). Do not use `0.0.0.0/0`.

The dashboard is published at HTTPS port 443 on the SOC host, IRIS at HTTPS port 8443, and Caldera at HTTP port 8888 on the attacker host. The OpenStack security group is the outer access control. IRIS's administrator password is generated and stored in `/root/.detection-lab-iris-password` on the SOC VM. Caldera creates its password in `/opt/detection-lab/caldera/conf/local.yml` on the attacker VM (the username is `red`). Wazuh's Docker stack ships with a default dashboard password; rotate it using Wazuh's documented Docker password procedure before widening access. These services are intended for a trusted lab network.

## Workflow

1. Confirm the target agent is active in Wazuh.
2. Launch an operation in Caldera using a stockpile adversary profile and the enrolled Caldera agent on the target. Caldera abilities include ATT&CK technique references.
3. Run individual Atomic Red Team tests from the attacker/target as appropriate; Atomic tests have prerequisites and cleanup steps. Review each test before execution.
4. Review events and alerts in Wazuh, write or tune rules under `infra/ansible/files/wazuh/rules/`, then promote relevant alerts into DFIR-IRIS cases.

The initial bootstrap does not automatically forward Wazuh alerts to IRIS; use Wazuh's integration/webhook API or IRIS alert API to connect them in a follow-up iteration. Both sides are usable independently from the initial deployment. To verify the sample Wazuh rule and telemetry path, write a marker to the target log: `echo 'detection-lab-atomic exercise marker' | sudo tee -a /var/log/detection-lab.log`. It should create a Wazuh alert mapped to ATT&CK T1059.004. The rule lives in `infra/ansible/files/wazuh/local_rules.xml` and is mounted into the manager container.

Caldera is ready at the printed URL. Deploy its Sandcat agent to the target from the Caldera UI (Agents → Deploy an agent) before running an operation; the UI generates the host-specific command. This keeps the implant tied to your Caldera server address. Caldera's Stockpile plugin supplies ATT&CK mapped abilities and adversary profiles. Atomic Red Team's test library is cloned onto the attacker for selecting individual exercises; tests may need per-target prerequisites and cleanup.

## Layout

```text
infra/                 OpenTofu network, security groups, instances
infra/ansible/         Ansible inventory and host configuration
lab                    deploy/configure/destroy helper
```

OpenTofu state is local by default. Keep `infra/terraform.tfstate*` private and back it up if you need the lab to survive a workstation loss. Do not commit state or generated inventories.
