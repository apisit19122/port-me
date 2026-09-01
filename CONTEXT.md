# Context: Port me

Glossary for the Port me domain. Terms only — no implementation detail.

## Process record

One process owned by the current user, as observed in a single scan: its pid, parent pid, executable path, and working directory. Port me never looks at processes owned by other users; it cannot inspect their sockets and must never signal them.

## Listener

A process record holding at least one TCP socket in the `LISTEN` state. UDP sockets and non-listening TCP sockets (established, time-wait) are not listeners — a port only counts as "occupied" when something is accepting on it.

A listener that binds both IPv4 and IPv6 on the same port is one listener on one port, not two.

## Process kind

Every process record is exactly one of three kinds, decided from its executable path:

- **System** — the executable lives in a path owned by macOS (`/System`, `/usr/libexec`, `/usr/sbin`, `/sbin`, `/Library/Apple`). Never listed and never signalled, at any setting. This is the meaning of the user's "ไม่ใช่ของระบบ": these are out of scope by definition, not merely hidden.
- **GUI app** — the executable lives inside a `.app` bundle that is not a system path (Chrome, OrbStack, VS Code helpers, Figma agent). Hidden by default because it is noise for the "my dev server is stuck" task, but a real target when [Show all](#show-all) is on.
- **Dev** — everything else. The dev servers, runtimes, and scripts the user started themselves.

Kind is a property of the executable's location, not of a maintained list of program names. There is no whitelist of `node`/`bun`/`pnpm` to keep up to date.

## Barrier

A process that a [dev tree](#dev-tree) must not grow past when walking towards its root. Barriers are interactive shells (`zsh`, `bash`, `fish`, …), terminal multiplexers, `launchd`, any System or GUI app process, and Port me's own process together with all of its ancestors.

A barrier is never a kill target. Stopping at the shell is what keeps Port me from killing the terminal the dev server was launched from.

## Dev tree

The set of processes belonging to one thing the user started. Its **root** is found by walking up from a listener through parents until a [barrier](#barrier) is reached; the tree is that root plus all of its descendants.

A dev tree exists because a single `pnpm dev` becomes several processes: the package manager, its wrapper, and the runtime that actually binds the port. The listener alone is not the unit the user thinks in — the tree is.

## Dev server

One [dev tree](#dev-tree) that contains at least one [listener](#listener). This is the unit Port me lists and kills: one row, one dev server.

A dev server can hold several ports, because several processes in one tree can each be listening (a monorepo running an API and a web app from one command is one dev server on two ports, not two dev servers). Its name comes from the listeners — they are what actually holds the port — and its project folder from the root's working directory.

## Kill

Ending a dev server: `SIGTERM` to the whole tree, root first so a supervisor cannot respawn what it is watching, then `SIGKILL` to whatever is still alive after the grace period.

Kill is not "signal the listener". Signalling only the listener leaves the package manager above it running, and killing bottom-up invites a respawn.

A kill **escalated** when the grace period expired with processes still alive and `SIGKILL` was needed. A kill **succeeded** when no process in the tree remains, whether or not it escalated.

## Show all

The setting that adds [GUI app](#process-kind) dev servers to the list. It never reveals System processes — those are outside the domain, not hidden by a preference.
