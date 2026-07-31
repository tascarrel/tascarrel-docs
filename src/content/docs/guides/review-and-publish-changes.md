---
order: 5
description: Inspect repository and overlay changes, approve host-share updates, and publish Git refs.
---

# Review and Publish Changes

Tascarrel keeps upstream Git credentials and shared object caches on the host.
Configured repositories appear at their declared paths below `/workspace`:

```toml
[repos."product/api"]
source = "git@github.com:example/api.git"
branch = "release/next"
```

Omit `branch` to check out the upstream's advertised default branch.

## Add a Repository to an Existing Pod

Repositories added to the workspace configuration are included in new pod
workspace seeds. To add one to an existing pod, start the pod, open its
**Repositories** tab, and select **Import** beside the absent checkout.

Tascarrel imports one prepared host-cache version and configures the checkout
for the same mediated fetch and push flow as a new pod. Import requires the
configured path to be absent. If a file or directory already occupies that
path, Tascarrel leaves it unchanged; move or remove the conflicting content
yourself, or create a new pod.

## Review the Pod

The **Changes** view shows modified, staged, deleted, and untracked files, along
with supported text diffs. It also reports commits ahead of or behind the local
tracking ref; displaying that comparison does not fetch from the network.

Pending overlay-share submissions appear in the same source list as changed
repositories. Repository sources retain their Git-specific branch, commit, and
history controls. Overlay sources instead show the submitted filesystem
revision and its added, modified, deleted, or replaced paths.

Run focused checks in a terminal and review the actual diff rather than relying
only on an agent summary.

## Review an Overlay Submission

A pod submits the current revision of an `Overlay` share with:

```console
podctl shares submit <SHARE>
```

Select that pod and open **Changes** in the host UI. Select the `/mnt/<SHARE>`
source to review its changed paths, existing and proposed entry types, and
proposed file sizes. Tascarrel also shows a unified patch when the captured and
proposed regular files are bounded UTF-8 text. Structural, binary, and large
file changes use metadata-only review. Overlay submissions do not have commits
or history.

**Approve** applies only the exact submitted revision. Tascarrel first checks
that the corresponding host entries have not changed independently, and it
writes nothing if it finds a conflict. **Reject** closes the request without
changing the host directory. If the pod changes its overlay after submitting,
the stale request cannot be approved; reject it and have the pod submit the
current revision.

## Set Publication Policy

Git pushes require approval by default. Configure ordered rules when some refs
need different treatment:

```toml
[git]
default-policy = "require-approval"

[[git.branches]]
pattern = "main"
policy = "deny"

[[git.branches]]
pattern = "automation/**"
policy = "allow"

[[git.tags]]
pattern = "**"
policy = "require-approval"
```

Policies are `allow`, `deny`, or `require-approval`. Patterns match short
branch or tag names. A single `*` stays within one slash-delimited component;
`**` crosses components. A repository can replace the workspace policy with
its own rules.

## Publish the Ref

Run a normal push from a configured checkout:

```console
git push origin HEAD
```

The remote transport carries the proposal through the workspace VM to the
host. An allowed push publishes immediately, a denied push fails, and a push
requiring approval waits for a decision in **Workspace → Repositories**.

The approval shows exact old and new object IDs and the commits introduced by
the updated refs. Select a commit to inspect its exact patch before approving,
rejecting, or postponing the publication. The review reads immutable objects
retained by the host, so it remains exact if the pod changes or disappears.
Publication retains the old values as leases, so a concurrent upstream change
fails closed. Multi-ref updates remain atomic.

Ref deletion is not supported. Arbitrary remotes do not gain access to
host-owned credentials.
