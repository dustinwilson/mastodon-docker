# Mastodon Docker #

[a]: https://joinmastodon.org
[b]: https://docs.joinmastodon.org/admin/install/
[c]: https://hub.docker.com/r/tootsuite/mastodon
[d]: https://pleroma.social
[e]: https://hub.docker.com/r/jordemort/pleroma
[f]: https://nginx.org
[g]: https://github.com/tootsuite/mastodon/blob/main/dist/nginx.conf

This is a Docker image for running [Mastodon][a]. It is built using a combination of the [official installation instructions][b], the [official Mastodon Docker container][c] (but doesn't inherit from it), and the `ubuntu:20:04` container.

# Why? #

Mastodon is incompatible with my server because just one of its monstrous amount of dependencies is dead and isn't compatible with Node 14 while another is incompatible with Node 13. I had to use a Docker container if I wanted to continue to run my single-user instance. Built it because Mastodon's own Docker container doesn't work as it only partially installs Mastodon into a container with no way to feed it Postgres or Redis. I would assume it's there just for people to build their own containers from, but it also includes an init system that can only handle a single process. Mastodon has *three* processes, so I'm not really sure what their intentions are.

# Warning #

Mastodon is a colossal mess that uses an immense amount of resources to run. This Docker container will be over 100MB in size, and that's only for Mastodon and its Everest-sized dependencies. I don't know if this will work for everyone, and if you're starting fresh I would suggest giving [Pleroma][d] a go first. Its Web interface, while very responsive, isn't as user friendly as Mastodon's. However, it uses only a fraction of the resources Mastodon does, is infinitely easier to set up, and equally easier to maintain. I am not using it only because I've ran my own Mastodon instance for almost three years in a subdomain while my actual account domain isn't the subdomain. Pleroma cannot do this while Mastodon has configurations for this. I've tried. Also, if you're wanting to run Pleroma in a container [this one][e] works really well.

# Configuration #

This container has two volumes:

* `/opt/mastodon/config`
* `/opt/mastodon/live/public/system`

The config folder should contain a `mastodon.conf` file. It is symlinked to `/opt/mastodon/live/.env.production` so that the configuration can reside in a volume. If the file does not exist it will be generated for you using either default values or supplied environment variables:

| Environment Variable       | Default value                          | Description                                                         |
| :------------------------- | :------------------------------------- | :------------------------------------------------------------------ |
| `LOCAL_DOMAIN`             | `example.com`                          | Domain for the instance                                             |
| `OTP_SECRET`               |                                        | Secret key used by Mastodon\*                                       |
| `PATH`                     | `$PATH:/opt/mastodon/live/bin`         | POSIX path environment variable                                     |
| `POSTGRES_DB`              | `mastodon`                             | Postgres database name                                              |
| `POSTGRES_HOST`            | `localhost`                            | Postgres hostname                                                   |
| `POSTGRES_PORT`            | `5432`                                 | Postgres port                                                       |
| `POSTGRES_USER`            | `mastodon`                             | Postgres database user                                              |
| `POSTGRES_PASS`            |                                        | Postgres database user password                                     |
| `SECRET_KEY_BASE`          |                                        | Secret key base used by Mastodon\*                                  |
| `SINGLE_USER_MODE`         | `false`                                | Flag to enable a single-user instance                               |
| `SMTP_SERVER`              | `localhost`                            | SMTP server Mastodon should use to email                            |
| `SMTP_PORT`                | `25`                                   | SMTP port                                                           |
| `SMTP_AUTH_METHOD`         | `none`                                 | Authorization method used when connecting to SMTP server            |
| `SMTP_OPENSSL_VERIFY_MODE` | `none`                                 | Verification method used when connecting to SMTP server             |
| `SMTP_FROM_ADDRESS`        | `Mastodon <notifications@example.com>` | Address Mastodon should email from                                  |
| `VAPID_PRIVATE_KEY`        |                                        | Private key used for push notifications\*                           |
| `VAPID_PUBLIC_KEY`         |                                        | Public key used for push notifications\*                            |
| `WEB_DOMAIN`               | `example.com`                          | Will only be different from LOCAL_DOMAIN if serving from subdomain  |

\* Generated if not supplied when running the container and a mastodon.conf file is not supplied in the `/opt/mastodon/config` volume.

The only thing the container won't do for you when starting a brand new instance is the admin user. Mastodon provides a generated password when creating the admin account which isn't ideal for automation like this, so to do that you do the following provided the name of your container is `Mastodon`:

```bash
docker exec -it Mastodon tootctl accounts create --confirmed --email EMAIL --role admin USERNAME
```

There are two ports the container exposes. Both are needed when configuring proxies in [Nginx][f]:

| Port | Description             |
| :--- | :---------------------- |
| 3000 | Web interface           |
| 4000 | Streaming (Web sockets) |

The [official example nginx configuration][g] is sufficient in getting this Docker container properly proxied with one exception: There is no need for a `root` directive as there's nothing locally to serve. However, if your `WEB_DOMAIN` environment variable is different than the `LOCAL_DOMAIN` one the following should be put into the server block that corresponds to the hostname specified in `WEB_DOMAIN` (replace `<LOCAL_DOMAIN>` with the value of the `LOCAL_DOMAIN` environment variable):

```nginx
location = /.well-known/host-meta {
    return 301 https://<LOCAL_DOMAIN>$request_uri;
}

location = /.well-known/webfinger {
    return 301 https://<LOCAL_DOMAIN>$request_uri;
}
```