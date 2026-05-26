# Secure Sandboxed AI Workstation (Airlock Architecture)

An isolated, security-first environment designed explicitly to execute AI workflows and untrusted LLM in ther terminal safely. By enforcing boundaries between the autonomous AI container and the host filesystem, this project eliminates the risk of a AI agents uncontrollably or with malicious intent compromising the host machine, while preserving a real-time, interactive development experience.

---

## Why This Project

Integrating Large Language Models (LLMs) directly into our local development workflows is incredibly powerful—whether it's building terminal-based AI agents, syncing an model with an Obsidian vault, or letting an agent interact with code editors. However, giving an untrusted AI model full executing privileges over your primary host machine is a massive security risk.

The standard solution many use to this problem is expensive: renting a dedicated VPS or dedicating a physically air-gapped machine (like a separate Mac Mini) purely for AI execution. For many developers, including myself, budgeting for dedicated hardware or recurring cloud bills just isn't feasible.

This project was born out of a desire for a different approach: a lightweight, budget-friendly, multi-container Docker architecture that creates a secure, sandboxed "clean room" for AI tool execution directly on your existing machine.

### What It Aims to Do (Scope & Security Boundaries)

This project is explicitly designed to handle the most common operational hazards of local "vibe coding" and agentic workflows, such as: Preventing Accidental Destruction, limiting Data Sprawl & Leaks, isolating Unprivileged Actions.

### What it is NOT designed to do:

This project is not a holistic, hypervisor-level security resolution. It is not engineered to mitigate sophisticated, malicious container-breakout exploits or direct zero-day attacks against the host operating system kernel. It is a practical boundary designed to absorb the chaos of AI hallucinations and erratic behaviour, giving you a safe playground to build and run local AI tools.

## Project Vision

The long-term goal of this project is to create a **completely portable and secure AI execution runtime**. 

Most modern AI coding platforms and agent frameworks prioritize ease-of-use, which often means mounting the host's root or user directories directly to an AI with elevated privileges. When an AI agent has the power to write code and execute it via an active shell, this presents a severe security vulnerability. This architecture turns that model upside down:
1. **Zero Trust AI Sandbox:** The environment where the AI models, agents, and executed scripts live has zero knowledge of and zero access to the host machine in form of containerised isolation.
2. **Strict Identity Enforcement:** Every action inside the sandbox is executed by a strictly unprivileged user matching a specific non-root UID/GID (`1000:1000`).
3. **Infrastructure as Code:** A portable, clean-room workstation that can be spun up on a local Windows machine or migrated cleanly to a remote server without leaving a footprint or altering permissions on the underlying host OS.

---

## Current Architecture & Working

The system currently implements a **Three-Tier Airlock Separation** using Docker containers, an unprivileged privilege-dropping engine (`su-exec`), and an active file synchronization layer (`Unison`).

[WINDOWS 11 HOST]

- Will hold the workspace in a single folder: ./host_in 

[MANAGER-BRIDGE CONTAINER]

- Multi-stage Alpine image running as root for initial boot     
- Uses an entrypoint script to dynamically chown mounts         
- Uses su-exec to securely drop privileges to devuser (UID 1000)
- Runs background Unison daemon to sync files in real-time      

[AI-CONTAINER ] 

- Dedicated AI agent / runtime workspace (tty/stdin_open)     
- Runs strictly as unprivileged devuser (UID 1000)            
- Complete network isolation except via specified bridges     
- Air-gapped from host storage; operates entirely out of /work


### Core Components Implemented:
* **Intermediary Manager (`manager-bridge`):** It mounts your local host directory (`./host_in`) and a private Docker volume (`tool-work-area`).
* **Privilege Demotion Flow:** The Manager starts its lifecycle as root to dynamically resolve directory permissions on host-bound drives, instantly executes a permission normalization routine, and drops down to user `1000:1000` via `su-exec` before handing control over to the Unison sync engine.
* **Autonomous Target (`ai-container`):** A streamlined Alpine-based workspace configured with interactive TTY streams (`tty: true`, `stdin_open: true`) reserved specifically for AI code execution and model interactions. It runs safely as an unprivileged entity, maintaining a completely detached workspace. In future this part of the system is planned to be made modular, where any CLI based AI interface can be used, also plans to be integrated with locally hosted models.

---

## Current Getting Started

### Prerequisites
* Docker is installed. (As of this update, this sytem is only tested in a Windows 11 enviroment with Docker Desktop installed (WSL2 backend) so this is recommended. This will most likely work on linux enviroment as well but hasnt been officially tested.)

### Project Layout
Ensure your directory structure looks exactly like this:
```
├── docker-compose.yml
├── Dockerfile          # Builder for the manager-bridge
├── entrypoint.sh       # Privilege-dropping and sync execution script
└── host_in/            # Your actual project source folder on your host
```

### Initial Spin-up

To compile the local Manager image for the first time and mount the safe workspace, run:

```
docker compose up -d
```

*Note: On all subsequent runs, Docker Compose will instantly reuse the cached local image without rebuilding it.*

### Entering the AI Workspace

To jump inside your secure AI development workspace:

```
docker exec -it ai-container gemini
```

### Verifying Isolation

You can confirm that privileges are isolated and process ownership is clean by checking user tracking and process structures inside the runtime containers:

```
# Check running UID/GID inside the AI sandbox
docker exec ai-container id

# Ensure Unison is running cleanly as PID 1 without lingering root processes
docker exec manager-bridge ps aux
```

---

## Future Roadmap

The architecture has been designed from day one to scale into an advanced, network-driven sandbox:

### Microservice Package Management via Nix API

* **Objective:** Give the unprivileged `ai-container` the ability to install any development library or AI tooling (Python, Node.js, openvpn, etc.) required for its tasks without allowing privilege escalation or expanding the base Docker image footprint from the compose file.
* **Design:** Implement an asynchronous **Service-Provider Pattern** over an internal network bridge. The Manager container will host a Nix package repository on a persistent volume. The AI container will query an internal, isolated API endpoint on the Manager to trigger package installations. Installed tools will appear instantly and immutably in the AI container's executable path.
* [Any suggestions and feedback for implementing this is highly appriciated]

### Phase 2: High-Volume Userspace Filesystems (SSHFS / FUSE)

* **Objective:** Graduate from Unison file syncing to a live network-based mounting setup when dealing with massive AI workspaces (e.g., thousands of script variants, dense repository indexing, or heavy dataset arrays) where file mirroring hits a mirroring/CPU bottleneck.
* **Design:** To bypass standard network filesystem (NFS) vulnerabilities—which require root-level kernel capabilities (`CAP_SYS_ADMIN`) inside Docker Compose—the architecture will migrate to **Filesystem in Userspace (FUSE) over SSHFS/SFTP**. The Manager container will securely serve the active files across an isolated internal backplane network, allowing the unprivileged `devuser` inside the AI container to mount the codebase without ever gaining root clearance over the virtual kernel.
* [Again any suggestions and feedback for implementing this is highly appriciated]
