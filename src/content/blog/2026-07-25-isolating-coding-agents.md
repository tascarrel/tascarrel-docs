---
slug: isolating-coding-agents
title: Isolating Coding Agents
description: |
  Safely running a coding agent requires isolating both the agent and all
  development code it executes, including dependencies, build scripts, tests,
  and project tools. This article explains why command approvals are not an
  isolation boundary, compares operating-system sandboxes, containers,
  user-space kernels, virtual machines, and dedicated machines, and examines
  the network, credential, publication, state, environment, and hosting
  decisions needed to make isolation effective in practice.
date: 2026-07-26
tags: [coding agents, isolation, security, development environments]
author:
  name: Maximilian Köhl
  href: https://silitics.com/
---

<!-- New introduction -->

A coding agent is useful precisely because it can act without waiting for you.
Give it a prompt and it can inspect the repository, edit files, install
dependencies, run the build, start the application, and iterate on the test
suite. That workflow delegates authority both to an agent whose decisions
cannot be trusted and to code the developer may never have reviewed. Running
this workflow on a trusted machine without appropriate safeguards is a disaster
waiting to happen.

Containing that risk requires an isolation boundary around both the agent and
the complete development environment. Developers can choose among several
techniques, from operating-system sandboxes and containers to user-space
kernels, VMs, and dedicated machines. This article surveys those options,
compares their strengths and weaknesses, and offers practical guidance for
choosing among them. It also identifies the infrastructure and controls that
any complete design must get right beyond the isolation mechanism itself.

**A note on bias:** We develop Tascarrel, a secure agentic development
workbench. We cover its architecture separately in
[Tascarrel's Isolation Model](/blog/how-tascarrel-isolates-coding-agents).

<!-- truncate -->

## The Isolation Problem

Developing on a trusted machine has always been a risky endeavour. Even before
coding agents, software supply chain attacks have been commonplace and developer
machines are valuable targets. One small typo in `cargo add` or `pip install` is
all it takes to find yourself running a malicious build script exfiltrating your
secrets or taking your files hostage.

Agents have made the problem even worse. Not only can they autonomously add
dependencies that you never vetted yourself at unprecedented scale and speed,
but they can also encounter prompt injection when searching for documentation,
simply misunderstand your instructions, or make mistakes because of
hallucinations.

The solution to these problems is a proper isolation boundary.

### What Is an Isolation Boundary?

An isolation boundary separates an execution environment from resources outside
it. Isolation does not require eliminating all interaction. It requires every
interaction with external resources to use an explicitly permitted path, with
everything else inaccessible.

For coding agents, the practical question is what resources the environment can
reach and what authority it can exercise. Can it read or modify files on the
trusted machine, call local services, or use devices? Which network destinations
can it reach? Which credentials and identities can it use or access? Can it push changes,
publish packages, or deploy software? The same limits must apply to the agent,
its built-in tools, shell commands, subprocesses, and the code they load.
Anything outside the permitted paths must remain inaccessible to all of them.

### Approvals Are Not Isolation

Command approvals were the primary security control in early coding-agent
workflows and remain so in many local workflows. An approval pauses execution
and asks the user whether to run a command in the ambient environment. If
approved, the command and everything it invokes inherit whatever files,
credentials, services, devices, and network access that environment exposes. A
command approval is therefore an execution gate, not an isolation boundary.
Relying on approvals in place of an isolation boundary creates three further
problems.

**The first problem is missing context.** The approval dialog shows the requested
command, not everything it will execute, how that code will use its authority,
or the state left by the agent's earlier actions. Even `cargo test` or
`pnpm install` may run code the agent has just added or modified alongside
unreviewed build scripts, dependencies, plugins, and subprocesses. Without
carefully reviewing the entire situation on every request, the user cannot
reasonably determine whether the command is safe to run.

**The second problem is approval fatigue.** An agent's routine development loop can
produce a stream of superficially similar requests. Repeated requests soon become
routine. Users will predictably begin approving commands by habit or select
“allow for this session” for a broad class of commands. Dangerous commands can
then slip through because they receive the same habitual or broad policy
approval as routine ones.

**The third problem is lost productivity.** Frequent approval requests require
the developer to closely follow the agent's inspect, edit, build, and test loop
and remain available. That eliminates delegation and parallel work.
A coding agent can deliver a net productivity gain only when its routine work
can proceed without continuous supervision. If every step requires the
developer's attention, the interruptions can easily harm productivity.

Approvals therefore cannot serve as an isolation boundary for an autonomous
development loop. They remain useful for rare, comprehensible actions across an
existing isolation boundary, such as pushing a Git ref, reaching a new service,
attaching a device, or making a secret available. The routine development loop
needs to run within fixed limits that do not depend on continuous supervision.
Approval can complement those limits. It cannot replace them.

## Isolation Techniques

The techniques below provide different ways to create an isolated execution
substrate. They differ in compatibility, cost, convenience, and boundary
strength. Here, strength means how likely untrusted code is to find an
unintended path out through a flaw in the enforcement mechanism or one of its
exposed interfaces.

### Operating-System Sandboxes

Operating-system sandboxes use controls built into the host operating system to
restrict what selected processes can access and do. Seatbelt on macOS and
bubblewrap on Linux are common choices. They are fast and compatible with an
existing development environment, but they share the workstation's kernel and
usually expose parts of its filesystem. A reachable flaw in the sandbox or host
kernel may therefore expose the workstation directly.

Current harnesses apply this approach differently:

- [Codex](https://learn.chatgpt.com/docs/agent-approvals-security#sandbox-and-approvals)
  enables a workspace profile by default. It permits workspace writes and
  blocks network access for spawned commands, but files outside the workspace
  remain readable unless the user adds a separate
  [deny-read configuration](https://learn.chatgpt.com/docs/permissions#file-access-limited-to-workspace).
- [Claude Code](https://code.claude.com/docs/en/sandboxing) offers an optional
  sandbox for Bash and its child processes. Its default read policy still
  includes the entire computer, including common credential files, unless those
  paths are explicitly denied. Docker is incompatible with the sandbox and
  must be excluded, causing it to run outside the boundary.
- [Gemini CLI](https://geminicli.com/docs/cli/cli-reference/) leaves sandboxing
  disabled by default. On macOS, its native sandbox uses Seatbelt and allows
  broad file reads and network access under the default profile.

These sandboxes are meaningful improvements over approval prompts. They are
well suited to limiting accidental writes and routine network access in a
development environment that is otherwise trusted. As commonly configured,
they are not a suitable isolation boundary against an agent or development
code that may actively seek confidential data on the trusted machine. Data
left readable is not isolated, regardless of write restrictions.

### Containers

Containers use operating-system isolation to give a group of processes a
separate view of filesystems, processes, users, and network resources while
sharing the container host's kernel. Development containers use that mechanism
to put the harness, development tools, and other processes into one
declared environment. Compared with a command-only sandbox,
this avoids many split-boundary problems: the shell, build tools, language
servers, and agent normally see the same filesystem and dependencies.

Some harnesses offer container-based environments directly.
[Claude Code documents a development container](https://code.claude.com/docs/en/devcontainer),
and [Gemini CLI can use Docker or Podman](https://geminicli.com/docs/cli/sandbox/)
for its sandbox. The security properties come from the container configuration,
not from the agent that runs inside it.

Containers can keep the host's home directory and unrelated data outside the
environment. The effective boundary, however, includes every mount, socket,
credential, network route, and kernel interface exposed by the configuration:

- **Writable mounts cross the filesystem boundary.** A bind-mounted checkout
  lets code in the container modify files on the host by design. IDEs, Git, and
  build tools may later consume those files outside the container, allowing
  container-controlled code to execute on the host without a container escape.
- **Convenience credentials remain usable.** Secrets passed through environment
  variables or configuration files can be read directly. SSH agents and cloud
  credential services can authorize operations even when the underlying secret
  is not present in the container.
- **Default networking often leaves egress open.** Code in the container may be
  able to exfiltrate source code and credentials or reach services on local and
  production networks. Container isolation does not impose those restrictions
  unless they are configured separately.
- **Privileged integrations can collapse the boundary.** Mounting the Docker
  socket lets the container start new containers with host mounts or
  elevated privileges. Docker documents that access to the daemon
  grants
  [root-level authority on the host](https://docs.docker.com/engine/install/linux-postinstall/).
  Host namespaces, privileged mode, and device passthrough create similar
  exposure.
- **Native Linux containers share the container host's kernel.** User
  namespaces, seccomp, mandatory access control, capabilities, and rootless
  runtimes reduce privileges and the reachable kernel surface, but do not
  create a separate kernel boundary. A runtime or kernel vulnerability can
  therefore turn a container escape into a host compromise.
  [NIST similarly notes that shared-kernel containers have a larger inter-object attack surface and provide less isolation than hypervisors](https://doi.org/10.6028/NIST.SP.800-190).
- **Docker Desktop adds an outer VM boundary.** Linux containers on macOS and
  Windows still share the Linux VM's kernel. The VM adds hardware-assisted
  isolation from the desktop host, but files and services explicitly shared
  through it remain directly available through those permitted paths.

Containers are an excellent reproducibility mechanism and can provide useful
containment when carefully hardened. Against code that may actively seek an
escape, however, a native container generally provides a weaker boundary than a
VM. A typical development container further favors convenience with a writable
checkout, open network, mounted credentials, and access to a container daemon.
In that configuration, escaping the container is often trivial.

### User-Space Kernels

A user-space kernel is a program that acts as the operating-system kernel for a
sandboxed workload. When the workload asks to open a file, create a process, or
use the network, the user-space kernel handles that request instead of passing
it directly to the host kernel. Untrusted code therefore encounters a separate
kernel implementation before it can reach the host kernel. This generally
provides a stronger boundary than a native container. The best-known example is
[gVisor](https://gvisor.dev/), which also allows using container tooling and
OCI images.

A user-space kernel is not a conventional VM. Its application kernel and the
components mediating its remaining access to the host must also be trusted.
Mounted files, credentials, and reachable networks remain exposed.
Reimplementing the Linux interface also introduces
[compatibility](https://gvisor.dev/docs/user_guide/compatibility/) and
[performance](https://gvisor.dev/docs/architecture_guide/performance/)
trade-offs.

These trade-offs make user-space kernels a poor default for general coding-agent
environments, whose tools and dependencies are difficult to predict in advance.
They may still be useful for fixed, pre-tested workloads when the resource cost
of a VM is unacceptable.

### Virtual Machines

Virtual machines put a separate guest kernel between development code and the
host. The guest interacts with a virtual hardware interface rather than
directly with the host kernel's system-call interface. Compromising the guest
kernel does not by itself compromise the host. An attacker must also exploit
the virtualization layer or abuse an explicit host integration.

VMs generally consume more memory and storage than containers and take longer
to start because each boots a guest kernel in its own virtual hardware
environment. MicroVMs are stripped-down VMs designed to reduce those costs.
[Firecracker](https://github.com/firecracker-microvm/firecracker/) is a well-known
example. Per-task microVMs are a strong fit for hosted, horizontally scaled
execution. Their minimal device model reduces the code exposed to a hostile
guest, lowering the likelihood that one vulnerability will provide an escape.

Conventional development VMs trade resource efficiency for broad compatibility.
They can accommodate toolchains and workflows that depend on Docker, Nix,
nested virtualization, complex networking, or long-lived services. They can be
prepared once, kept running or suspended, and reused as complete development
workspaces. This makes their higher provisioning and resource costs easier to
justify for interactive work.

Hosted environments make this model more convenient. A provider can provision
VMs, maintain images, resume workspaces, create parallel environments, and
provide remote access without consuming resources on the developer's
workstation. Hosting is not a separate isolation technique. It moves the VM and
its operation to a provider, which must then be trusted with the source code,
task data, and enforcement of the boundary.

VMs are a strong general-purpose choice for isolating coding agents and
development code that may actively attack the boundary. They preserve broad
tool compatibility at the cost of greater resource use and operational
complexity. They still require careful control of host integrations,
networking, and credentials, but unlike native containers they do not expose
the host kernel directly to the workload.

### Dedicated Machines

A separate physical computer provides a clean hardware boundary from the
developer's primary workstation. That separation does not rely on a shared
kernel or hypervisor: compromising its operating system does not directly
compromise the primary workstation through a shared software stack. A dedicated
machine may therefore be reasonable for a high-risk project.

Physical separation does not solve network or credential security:

- With ordinary internet access, malicious code can still exfiltrate the
  project's source, build artifacts, prompt context, and any credentials on the
  machine.
- A machine attached to the same home or corporate network may reach local
  services or attack other systems unless the network separates it.
- A useful agent commonly needs access to a model provider, source repository,
  package registry, or a way to return changes. Copying general-purpose
  credentials onto the machine gives untrusted development code those
  credentials.
- An air gap prevents direct egress, but it also prevents a hosted model call
  and ordinary dependency downloads. Moving inputs and results across the gap
  becomes its own controlled interface.

A dedicated machine provides physical separation, not a complete isolation
design. It still needs constrained egress, narrowly scoped or mediated
credentials, a controlled publication path, and a reimaging strategy. It also
has practical costs: physical provisioning, slower reset, limited parallelism,
and more state to patch and inventory.

## The Missing Pieces

Isolating execution is not enough. The techniques above provide an isolated
execution substrate for the agent and development code. They separate that
execution from the trusted environment and determine how difficult it is for
code to escape. But as established earlier, a complete isolation boundary also
includes every explicitly permitted path between the environment and external
resources. None of these techniques decides by itself which files and services
in the trusted environment, network destinations, credentials, or publication
paths remain accessible. Nor does it decide how the environment is built, where
it runs, who operates it, or which state persists between tasks.

These are not secondary details. A VM or dedicated machine with unrestricted
network access and production credentials still lets the workload exfiltrate
data or act on production systems without escaping anything. The execution
substrate, permitted external interactions, environment definition, state
lifecycle, and hosting model must therefore be designed together.

Permitted paths also become part of the boundary's attack surface. In July
2026, OpenAI
[reported preliminary findings](https://openai.com/index/hugging-face-model-evaluation-security-incident/)
from an advanced cyber-capability evaluation in which network access was
limited to an internal package-registry proxy. The models exploited a zero-day
in that proxy, moved laterally to an Internet-connected node, and then
compromised Hugging Face infrastructure. The evaluation intentionally omitted
production safeguards and is not representative of ordinary coding-agent use.
The broader lesson is that every reachable proxy, mount, socket, and service is
part of the boundary, while every credential within reach increases the
consequences of a breach.

- **External integrations must remain narrow.** Filesystem mounts, daemon
  sockets, local services, devices, IDE automation, and other facilities
  outside the execution substrate can all carry data or execution across the
  boundary. Anything exposed this way should be treated as available to the
  agent and development code.
- **Network access must match the task.** Moving execution into a container, VM,
  or separate machine does not constrain egress or prevent access to local
  networks. Internet destinations, private addresses, listening ports, DNS, and
  every proxy through the boundary need deliberate limits.
- **Credentials must carry only the required authority.** Injecting a secret
  into an isolated environment makes it available to everything inside that
  environment. General-purpose Git, registry, cloud, and production credentials
  should be replaced with narrowly scoped, short-lived credentials or mediated
  operations that keep the credential outside the boundary.
- **Publication must be separate from modification.** Permission to edit a
  working tree need not imply permission to push a branch, publish a package, or
  deploy an application. Those transitions should cross a narrow interface that
  can authorize the specific operation.
- **Environment definitions must be reusable and shareable.** Toolchains,
  services, setup steps, and non-secret configuration should be captured in
  versioned files that teams can review, rebuild, and apply consistently.
  Hand-configured environments drift and turn each isolated workspace into a
  one-off system.
- **Persistent state can carry compromise between tasks.** Shared caches,
  services, and tool state may carry compromised artifacts or configuration
  into later work, while persistent credentials remain available to later
  workloads. Their scope and lifetime must be explicit, with disposable task
  state wherever persistence is unnecessary.
- **Hosting changes who must be trusted.** A hosted environment separates the
  workload from the developer's workstation, but the provider operates the
  isolation boundary and receives source code and task data. Its underlying
  mechanism, tenant separation, credential handling, network controls,
  retention, and method for returning results all need evaluation.

An isolation design must therefore identify the enforcement mechanism, every
permitted path through the boundary, and who operates each component. A strong
mechanism cannot compensate for overly broad access deliberately granted
through those paths.

### Common Integration Traps

Several convenient integrations can quietly reconnect an isolated workload to
the trusted environment. The isolation mechanism may remain intact. The problem
is that a service or tool outside the boundary accepts instructions or consumes
files controlled from inside it.

**Docker daemon access can collapse the boundary.** If a Docker daemon in the trusted
environment is exposed to the workload, the workload can ask it
to start privileged containers or mount files from the daemon's machine. Docker
documents that access to the conventional daemon grants
[root-level authority on that machine](https://docs.docker.com/engine/install/linux-postinstall/).
A development workflow that requires a Docker daemon should run it inside the
same isolation boundary or expose only narrowly mediated operations instead of
the general daemon API.

**A shared writable working tree can become an execution channel.** If the
agent and unsandboxed tools outside the boundary share a working tree, the agent
controls future inputs to those tools. When an external tool consumes that
input, agent-controlled code may execute with the developer's ambient access.

**Git hooks are one direct example.** Git executes programs from
`$GIT_DIR/hooks` or the directory selected by
[`core.hooksPath`](https://git-scm.com/docs/githooks). If the agent can modify
that directory, a later Git operation outside the boundary may execute
agent-written code. Protecting `.git` closes the default path, but not a hooks
path that the developer has configured inside the writable working tree.

**IDE automation creates many more paths.** Language servers, tasks, debuggers,
formatters, test watchers, and extensions may execute project-controlled code
in response to file changes. For example,
[rust-analyzer runs build scripts by default](https://rust-analyzer.github.io/book/configuration#rust-analyzercargobuildscriptsenable)
and invokes `cargo check`, which can
[compile and execute `build.rs`](https://doc.rust-lang.org/cargo/reference/build-scripts.html).
VS Code's
[Workspace Trust documentation](https://code.visualstudio.com/docs/editing/workspaces/workspace-trust)
restricts these features for precisely this reason. An IDE that already trusts
the working tree may run them in the trusted environment while the agent's own
shell remains sandboxed.

These examples are not exhaustive, which makes the problem difficult to solve
with a list of protected files or sockets. Every service and program that
accepts instructions or consumes agent-writable state must run inside the same
isolation boundary, or treat that input as untrusted until it has been reviewed.

## Conclusion

Coding agents add an untrusted actor to a development environment that already
executes dependencies, build scripts, tests, plugins, and project tools. An
effective isolation boundary must contain both the agent and that complete
development workflow, including every tool allowed to consume agent-writable
state without review.

There is no universally best mechanism. An operating-system sandbox is
practical when the repository and toolchain are trusted and the main concern is
accidental damage. A hardened development container creates a more coherent
environment, but a native container still shares the host kernel. A user-space
kernel reduces that exposure, but compatibility concerns make it a poor default
for open-ended development work. When the agent or development code may
actively attack the boundary, a VM provides stronger isolation. A dedicated
machine adds physical separation for exceptional cases, but still does not
constrain egress or protect credentials placed on it.

Choosing the mechanism is only half of the design. How the environment is
defined and reused, which paths it permits, how long its state persists, and
who operates it must be equally deliberate. In the companion article,
[Tascarrel's Isolation Model](/blog/how-tascarrel-isolates-coding-agents),
we show how Tascarrel addresses this complete set of concerns using reusable
environment definitions, local workspace VMs, disposable task pods,
host-mediated network access and Git publication, and selective credential
mediation.
