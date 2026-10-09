+++
title = "A SQLite Virtual Table Extension for Kubernetes"
date = 2026-10-05

[taxonomies]
categories = ["blog"]
tags = ["sqlite", "kubernetes", "rust"]
+++

I manage Kubernetes clusters at `$DAY_JOB`, and recently stumbled across a
[post](https://news.ycombinator.com/item?id=49415271) referencing SQLite _virtual
tables_. From the comments I came to realize what they were - ways to expose SQL
interfaces via SQLite, while soruce data using custom programs. I'm vaguely aware
of tools like [`osquery`](https://osquery.io/) that expose SQL shells for querying
data, but this was the first time I was aware of this being loadable from a `sqlite3`
shell directly! I decided to play with it and created [`kubernetes-vtab`](https://github.com/bradschwartz/kubernetes-vtab),
a sqlite3 virtual table extension built in Rust.

<!-- more -->

It's pretty straightforward. `kubernetes-vtab` is built on top of two Rust crates:

1. [`kube-rs`](https://kube.rs/) for querying the Kubernetes API
1. [`sqlite-loadable-rs`](https://github.com/asg017/sqlite-loadable-rs) for the extension framework

The goal of `kubernetes-vtab` is to be able to fetch data from live Kubernetes clusters
directly from sqlite, basically giving us a new `--output` format for kubectl.
This is mainly just a POC for me to get familiar with these technologies but it is cool
to see it working.

`sqlite-loadable-rs` makes things easy by defining some traits we have to
implement. We define our table structure:

```rust
#[repr(C)]
struct KubernetesTable {
    base: sqlite3_vtab,
    resource: String,
}
```

Because sqlite is written in C, we target the shared C ABI using `repr[C]`.

Next, we implement our Virtual Table Cursor. This is where things take shape,
although my implementation is currently very mechanical and each Kubernetes resources
has to be implemented and listed out. Since I want to support querying multiple
different resources, we actually abstract over the cursor using an Enum.

I've currently implemented querying the Kubernetes API for Pods and Deployments
(and a local-only debug resource). As new resources are added, I'll have to
ensure they're captured in the `Enum` here:

```rust
#[repr(C)]
enum KubernetesCursor {
    Pods {
        #[allow(dead_code)]
        base: sqlite3_vtab_cursor,
        pods_cursor: PodsCursor,
    },
    Debug {
        #[allow(dead_code)]
        base: sqlite3_vtab_cursor,
        debug_cursor: DebugCursor,
    },
    Deployments {
        #[allow(dead_code)]
        base: sqlite3_vtab_cursor,
        deployments_cursor: DeploymentsCursor,
    },
}
```

And then actually implementing the `VTabCursor` trait for the `Enum`. Some of the
implementations are hidden in their own module files.

```rust

impl VTabCursor for KubernetesCursor {
    fn filter(
        &mut self,
        idx_num: c_int,
        idx_str: Option<&str>,
        values: &[*mut sqlite3_value],
    ) -> Result<()> {
        match self {
            KubernetesCursor::Pods { pods_cursor, .. } => {
                pods_cursor.filter(idx_num, idx_str, values)
            }
            KubernetesCursor::Debug { debug_cursor, .. } => {
                debug_cursor.filter(idx_num, idx_str, values)
            }
            KubernetesCursor::Deployments {
                deployments_cursor, ..
            } => deployments_cursor.filter(idx_num, idx_str, values),
        }
    }

    fn next(&mut self) -> Result<()> {
        match self {
            KubernetesCursor::Pods { pods_cursor, .. } => pods_cursor.next(),
            KubernetesCursor::Debug { debug_cursor, .. } => debug_cursor.next(),
            KubernetesCursor::Deployments {
                deployments_cursor, ..
            } => deployments_cursor.next(),
        }
    }

    fn eof(&self) -> bool {
        match self {
            KubernetesCursor::Pods { pods_cursor, .. } => pods_cursor.eof(),
            KubernetesCursor::Debug { debug_cursor, .. } => debug_cursor.eof(),
            KubernetesCursor::Deployments {
                deployments_cursor, ..
            } => deployments_cursor.eof(),
        }
    }

    fn column(&self, context: *mut sqlite3_context, i: c_int) -> Result<()> {
        match self {
            KubernetesCursor::Pods { pods_cursor, .. } => pods_cursor.column(context, i),
            KubernetesCursor::Debug { debug_cursor, .. } => debug_cursor.column(context, i),
            KubernetesCursor::Deployments {
                deployments_cursor, ..
            } => deployments_cursor.column(context, i),
        }
    }

    fn rowid(&self) -> Result<i64> {
        match self {
            KubernetesCursor::Pods { pods_cursor, .. } => pods_cursor.rowid(),
            KubernetesCursor::Debug { debug_cursor, .. } => debug_cursor.rowid(),
            KubernetesCursor::Deployments {
                deployments_cursor, ..
            } => deployments_cursor.rowid(),
        }
    }
}
```

As you can see it's very redundant right now, but it at least has allowed me to abstract
each of the resource types into it's own module, keeping the code tidy. Each resource
also implements the `VTabCursor` trait, calling the Kubernetes API and organizing the
data as needed.

On top of the cursor we then implement the `VTab` trait, which is actually
the interface we end up exposing to users of the sqlite3 CLI. `sqlite-loadable-rs`
provides _some_ niceties for parsing the `CREATE TABLE` arguments, meaning when
someone uses the extension like:

```sql
sqlite> CREATE VIRTUAL TABLE pods USING kubernetes_vtab(resource='pods');
```

I get a nice structured object I can use to do any validations I might want - like
ensuring `resource`'s are always specified!

Once again, there's a lot of manually specifying the resource type exhaustively:

```rust
// 3. Register the extension initialization hook
impl<'vtab> VTab<'vtab> for KubernetesTable {
    type Aux = ();
    type Cursor = KubernetesCursor;

    fn connect(
        _db: *mut sqlite3,
        _aux: Option<&Self::Aux>,
        args: VTabArguments,
    ) -> Result<(String, Self)> {
        // Define the SQL schema your virtual table exposes
        let arguments = args
            .arguments
            .iter()
            .map(|arg| vtab_argparse::parse_argument(arg).unwrap())
            .collect::<Vec<vtab_argparse::Argument>>();
        // require `resource` argument, as that's how we know if it's Pods/Deployments/etc
        let resource = get_resource(&arguments)?;
        let schema = match resource {
            "pods" => pods::Pods::schema(),
            "deployments" | "deploy" => deployments::Deployments::schema(),
            "debug" => debug::Debug::schema(),
            _ => {
                return Err(sqlite_loadable::Error::new(
                    sqlite_loadable::ErrorKind::Message(format!("Unknown resource: {}", resource)),
                ))
            }
        };
        let vtab = KubernetesTable {
            base: unsafe { mem::zeroed() },
            resource: resource.to_string(),
        };
        Ok((schema, vtab))
    }

    fn best_index(&self, _info: IndexInfo) -> core::result::Result<(), BestIndexError> {
        Ok(())
    }

    fn open(&mut self) -> Result<Self::Cursor> {
        match self.resource.as_str() {
            "pods" => Ok(KubernetesCursor::Pods {
                base: unsafe { mem::zeroed() },
                pods_cursor: PodsCursor {
                    base: unsafe { mem::zeroed() },
                    row_id: 0,
                    pods: vec![],
                },
            }),
            "deployments" | "deploy" => Ok(KubernetesCursor::Deployments {
                base: unsafe { mem::zeroed() },
                deployments_cursor: DeploymentsCursor {
                    base: unsafe { mem::zeroed() },
                    row_id: 0,
                    deployments: vec![],
                },
            }),
            "debug" => Ok(KubernetesCursor::Debug {
                base: unsafe { mem::zeroed() },
                debug_cursor: DebugCursor {
                    base: unsafe { mem::zeroed() },
                    row_id: 0,
                },
            }),
            _ => unreachable!(),
        }
    }
}
```

And finally we use the library's macro for registering the extension:

```rust
#[sqlite_entrypoint]
fn sqlite3_extension_init(db: *mut sqlite3) -> Result<()> {
    define_virtual_table::<KubernetesTable>(db, "kubernetes_vtab", None)?;
    Ok(())
}
```

With all of this implemented, it's just a matter of compiling it into a loadable object
compatible with your system, and pointing sqlite at it:

```sql
sqlite> .load target/release/libkubernetes_vtab.dylib
sqlite> CREATE VIRTUAL TABLE pods USING kubernetes_vtab(resource='pods');
-- load some data!
sqlite> select * from pods ;
╭─────────────────────────────────────────────────────────────────┬─────────────┬─────────┬───────────────╮
│                              name                               │  namespace  │ status  │ restart_count │
╞═════════════════════════════════════════════════════════════════╪═════════════╪═════════╪═══════════════╡
│ arc-systems-gha-runner-scale-set-controller-gha-rs-controlcfchx │ arc-systems │ Running │             1 │
│ raspberrypi-57f574cf-listener                                   │ arc-systems │ Running │             1 │
│ helm-controller-5984cc88cf-6kh9s                                │ flux-system │ Running │             1 │
│ kustomize-controller-d6bb746df-sdthm                            │ flux-system │ Running │             1 │
│ notification-controller-7bc5c97f8d-swpjc                        │ flux-system │ Running │             1 │
│ source-controller-745c67ff9-6jmx7                               │ flux-system │ Running │             1 │
│ coredns-8db54c48d-wj6hd                                         │ kube-system │ Running │             1 │
│ local-path-provisioner-5d9d9885bc-69psk                         │ kube-system │ Running │             1 │
│ metrics-server-786d997795-pr5gs                                 │ kube-system │ Running │             1 │
│ operator-67f649cf9d-vpxnn                                       │ tailscale   │ Running │             1 │
╰─────────────────────────────────────────────────────────────────┴─────────────┴─────────┴───────────────╯
sqlite> select count(*) from pods ;
╭──────────╮
│ count(*) │
╞══════════╡
│       10 │
╰──────────╯
```

Right now it always loads from all namespaces, and uses whatever `kube-rs` picks up
as the current context via `$HOME/.kube/config`, without ways to override either, and only
supports Pods and Deployments. I think there's definitely some quick wins to gain
by supporting more resources, as well as marking a new `raw` column as `HIDDEN` in order
to give users an escape hatch to getting all data for the resource.

Something like:

```sql
sqlite> CREATE VIRTUAL TABLE daemonsets USING kubernetes_vtab(resource='daemonsets', namespace='my-namespace', context='other-context');
```

Past that, I think implementing filters would be the next logical step. The above
example sets all of these as static fields, which actually makes the code somewhat
bloated and passes state around everywhere, and makes the user API a bit less-obvious.
I'd much prefer to be able to specify things at query time like:

```sql
sqlite> CREATE VIRTUAL TABLE daemonsets USING kubernetes_vtab(resource='daemonsetes');
sqlite> SELECT *
        FROM daemonsets
        WHERE namespace = 'my-namespace';
```
