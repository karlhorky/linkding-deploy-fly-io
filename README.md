# Deploy linkding to Fly.io

> 🔖 Run the self-hosted bookmark service [linkding](https://github.com/sissbruecker/linkding) on [fly.io](https://fly.io/) with a persistent Fly volume for SQLite storage.

### Pricing

Assuming one 512MB VM and a 1GB volume, this setup should fit within a $5/month Fly waiver. [^0]

[^0]: Based on Fly's current pricing, a shared-cpu-1x 512MB machine is roughly $3.2-$4.2 per month depending on region, plus about $0.15/GB per month for the persistent volume.

### Prerequisites

- A [fly.io](https://fly.io/) account
- `flyctl` CLI installed. [^1]

[^1]: https://fly.io/docs/getting-started/installing-flyctl/

Instructions below assume that you have cloned this repository to your local computer:

```sh
git clone https://github.com/karlhorky/linkding-on-fly-no-backblaze && cd linkding-on-fly-no-backblaze
```

### Usage

1. Login to [`flyctl`](https://fly.io/docs/getting-started/log-in-to-fly/):

   ```sh
   flyctl auth login
   ```

2. Generate the initial [`fly.toml`](https://fly.io/docs/reference/configuration/) without deploying:

   ```sh
   # Generate the initial fly.toml
   # Optionally set a custom app name with: --name your-app-name
   # When asked, don't create a .dockerignore from the .gitignore.
   flyctl launch --no-deploy
   ```

3. Add the following `env` and `mounts` sections to `fly.toml`:

   ```toml
   [env]
     # linkding's internal port, should be 8080 on fly.
     LD_SERVER_PORT="8080"
     # Path to linkding's sqlite database.
     DB_PATH="/etc/linkding/data/db.sqlite3"

   [mounts]
     source="linkding_data"
     destination="/etc/linkding/data"
   ```

4. Create a [persistent volume](https://fly.io/docs/reference/volumes/) in the same region as your app to store the `linkding` application data:

   ```sh
   # List available regions via: flyctl platform regions
   flyctl volumes create linkding_data --region <region code> --size 1 --count 1
   ```

   > **Note**  
   > Fly's free tier includes `3GB` of storage across your VMs. Since `linkding` is very light on storage, a `1GB` volume will be more than enough for most use cases. It's possible to change volume size later. A how-to can be found in the _"Scale Persistent Volume"_ section below.

5. Add the `linkding` superuser credentials to fly's secret store:

   ```sh
   read -s LD_SUPERUSER_PASSWORD
   flyctl secrets set LD_SUPERUSER_NAME="<username>" LD_SUPERUSER_PASSWORD="$LD_SUPERUSER_PASSWORD"
   ```

6. Deploy `linkding` to fly:

   ```sh
   flyctl deploy
   ```

   > **Note**  
   > This setup is intended to run as a single Machine with a single SQLite-backed volume. Do not scale it to multiple Machines unless you also change the storage architecture.

That's it! If all goes well, you can now access `linkding` by running `flyctl open`. You should see the `linkding` login page and be able to log in with the superuser credentials you set in step 5.

If you wish, you can [configure a custom domain for your install](https://fly.io/docs/app-guides/custom-domains-with-fly/).

### Verify the Installation

- You should be able to log into your linkding instance.
- Your user data should survive a restart of the VM.

### Scale Persistent Volume

Fly volumes persist across VM restarts, but they are not a substitute for your own backup strategy. Before deleting or replacing a volume, make a manual backup of your data by copying the SQLite database from the VM or exporting bookmarks as HTML.

Now list all fly volumes and note the id of the `linkding_data` volume. Then, delete the volume:

```sh
flyctl volumes list
flyctl volumes delete <id>
```

This will result in a **dead** VM after a few seconds. Create a new `linkding_data` volume, then redeploy or restart the app so it can mount the replacement volume.

### Troubleshooting

#### Fly ssh does not connect

Check the output of `flyctl doctor`, every line should be marked as **PASSED**. If `Pinging WireGuard` fails, try `flyctl wireguard reset` and `flyctl agent restart`.

#### Fly does not pull in the latest version of linkding

- Override the [Dockerfile](Dockerfile#L2) build argument `LINKDING_IMAGE_TAG`: `flyctl deploy --build-arg LINKDING_IMAGE_TAG=<tag>`
- Run `flyctl deploy` with the `--no-cache` option.

#### Create a linkding superuser manually

If you have never used fly's SSH console before, begin by setting up fly's ssh-agent:

```sh
flyctl ssh establish

# use agent if possible, otherwise follow on-screen instructions.
flyctl ssh issue --agent
```

Then, run `flyctl ssh console` to get an interactive shell in your running container. You can now create a superuser by running the `createsuperuser` command and entering a password.

```sh
cd /etc/linkding
python manage.py createsuperuser --username=<your_username> --email=<your_email>
exit
```

### Credits

- Mostly taken from [`fspoettel/linkding-on-fly`](https://github.com/fspoettel/linkding-on-fly) by [Felix Spöttel](https://github.com/fspoettel)
- 256MB RAM Fly.io machine memory issue fixes by [Karl Horky](https://github.com/karlhorky)
- Simplification and removal of Backblaze backup by [Karl Horky](https://github.com/karlhorky)
