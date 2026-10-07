# athens

This project allows to deploy the [Athens Go module proxy](https://github.com/gomods/athens) on [deplo.io](https://docs.nine.ch/docs/deplo-io/dockerfile-build/).
It caches public modules from `proxy.golang.org` in [Nine Object Storage](https://docs.nine.ch/docs/storage/object-storage/).

```
go client ──> Athens (Deploio) ──hit──> module served from the bucket
                    │
                    └─miss──> 301 to proxy.golang.org, module is fetched into the bucket in the background
```

Only public modules are supported. Private modules would need `direct`, VCS credentials and authentication in front of Athens.

## Deploy

Requires [`nctl`](https://docs.nine.ch/docs/nctl/) and a fork or copy of this repository Deploio can access.

1. Log in, then create a project and make it the default for the following commands:

   ```sh
   nctl auth login
   nctl create project org-athens --wait
   nctl auth set-project org-athens
   ```

2. Create a bucket and a user that can write to it, in the same location as Deploio:

   ```sh
   nctl create bucketuser athens --location=nine-es34 --wait
   nctl create bucket athens --location=nine-es34 --permissions=writer=athens --wait
   ```

3. Create the application. The bucket user's keys are read from `nctl` directly:

   ```sh
   nctl create application athens \
     --git-url=https://github.com/thde/deploio-athens.git \
     --dockerfile \
     --health-probe-path=/healthz \
     --env='ATHENS_S3_BUCKET_NAME=athens;AWS_ENDPOINT=https://es34.objects.nineapis.ch' \
     --sensitive-env="AWS_ACCESS_KEY_ID=$(nctl get bucketuser athens --print-access-key);AWS_SECRET_ACCESS_KEY=$(nctl get bucketuser athens --print-secret-key)"
   ```

4. Get the app's URL. It is also listed in the `HOSTS` column of `nctl get application athens`:

   ```sh
   nctl get application athens -o json | jq -r '.status.atProvider.defaultURLs[0]'
   ```

5. Verify it serves modules:

   ```sh
   curl -fsS <app-url>/github.com/google/uuid/@v/list
   ```

6. Point your Go client at it. Checksums are still verified against `sum.golang.org`:

   ```sh
   go env -w GOPROXY=<app-url>,https://proxy.golang.org,direct
   ```

## Configuration

Athens starts one `go` process per background fetch.
Unless `ATHENS_GOGET_WORKERS` is set, the entrypoint sets it dynamically based on the memory available. Without a memory limit, Athens' default of 10 applies.

The `Dockerfile` extends the upstream `gomods/athens` image and runs it as its unprivileged `athens` user instead of root.
To deploy a different Athens release, pass it as a build argument, e.g. `nctl update application athens --build-env=ATHENS_VERSION=v0.19.1`.
