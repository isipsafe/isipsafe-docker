# isipsafe Docker image

Official Docker image for [isIPsafe](https://isipsafe.com), the free IP reputation and abuse reporting service. Official usage and deployment guide: [isipsafe.com/integrations/docker](https://isipsafe.com/integrations/docker).

- Check and report IP addresses from any machine with Docker, nothing to install
- Keep a firewall-ready **blocklist in sync** on a shared volume, for nginx, Apache, nftables, ipset or MikroTik
- Small Alpine image, runs as a non-root user, `linux/amd64` and `linux/arm64`

```bash
docker pull isipsafe/isipsafe
```

The image wraps the [isipsafe Python CLI](https://github.com/isipsafe/isipsafe-python).

## Get an API key

Lookups work without a key. Reporting and the blocklist need a free key from [isipsafe.com/login](https://isipsafe.com/login). Pass it as the `ISIPSAFE_API_KEY` environment variable, preferably with `--env-file` so it stays out of your shell history.

## Check and report

```bash
docker run --rm isipsafe/isipsafe check 185.220.101.1
docker run --rm isipsafe/isipsafe check 185.220.101.1 --json

docker run --rm --env-file .env isipsafe/isipsafe \
  report 203.0.113.50 -c ssh,brute-force -m "sshd: 212 failed logins"

docker run --rm --env-file .env -v "$PWD:/data" isipsafe/isipsafe bulk-report reports.csv
```

Every command of the CLI is available: `check`, `report`, `bulk-report`, `reports`, `check-block`, `blocklist`, `clear`, `categories`. Run `docker run --rm isipsafe/isipsafe --help` for the full list.

`check --fail-if-malicious` exits with status `1` when an address is malicious, so you can use it in scripts:

```bash
if ! docker run --rm isipsafe/isipsafe check "$IP" --fail-if-malicious >/dev/null; then
  echo "blocking $IP"
fi
```

## Keep a blocklist in sync

`sync-blocklist` downloads the blocklist every 30 minutes and writes it atomically to `/data`. If a download fails, or comes back empty, the previous list is kept, so your firewall never ends up empty.

```bash
docker run -d --name isipsafe-blocklist --restart unless-stopped \
  --env-file .env \
  -e BLOCKLIST_FORMAT=nginx \
  -e BLOCKLIST_OUTPUT=/data/isipsafe-blocklist.conf \
  -v isipsafe-blocklist:/data \
  isipsafe/isipsafe sync-blocklist
```

Run it once and exit (for cron or CI) with `sync-blocklist --once`.

| Variable | Default | Meaning |
| --- | --- | --- |
| `ISIPSAFE_API_KEY` | (required) | Your API key |
| `BLOCKLIST_FORMAT` | `txt` | `txt`, `csv`, `json`, `stix`, `ipset`, `nftables`, `nginx`, `apache`, `mikrotik` |
| `BLOCKLIST_OUTPUT` | `/data/blocklist.txt` | Where to write the list |
| `BLOCKLIST_INTERVAL` | `1800` | Seconds between downloads (minimum 300) |
| `BLOCKLIST_CONFIDENCE_MINIMUM` | `75` | Only addresses with at least this score (1-100) |
| `BLOCKLIST_DAYS` | `30` | Only addresses reported in the last N days (1-90) |
| `BLOCKLIST_LIMIT` | `10000` | Maximum number of addresses |
| `BLOCKLIST_IP_VERSION` | both | `4` or `6` |
| `BLOCKLIST_ONLY_COUNTRIES` | | ISO codes, e.g. `CN,RU` |
| `BLOCKLIST_EXCEPT_COUNTRIES` | | ISO codes, e.g. `GB,IE` |

### With nginx

[`examples/docker-compose.yml`](examples/docker-compose.yml) runs the sync container next to nginx with a shared volume. nginx includes the generated file:

```bash
cd examples
echo "ISIPSAFE_API_KEY=sl_your_key_here" > .env
docker compose up -d
```

Reload nginx after an update to apply the new list (for example `docker compose exec nginx nginx -s reload` from cron).

## Tags

- `latest`: the newest release
- `0.1.0`, `0.1`: a specific release

## Build it yourself

```bash
docker build -t isipsafe .
sh tests/test.sh   # IMAGE=isipsafe sh tests/test.sh
```

To build from a local wheel of the Python package instead of PyPI, copy the `.whl` into `wheels/` before building.

## Links

- Official Usage Page: [isipsafe.com/integrations/docker](https://isipsafe.com/integrations/docker)
- Docker Hub: [hub.docker.com/r/isipsafe/isipsafe](https://hub.docker.com/r/isipsafe/isipsafe)
- Website: [isipsafe.com](https://isipsafe.com)
- API reference: [isipsafe.com/api](https://isipsafe.com/api)
- Integrations: [isipsafe.com/integrations](https://isipsafe.com/integrations)

## Licence

The code in this repository is MIT licensed. Data returned by the isIPsafe API is covered by the [isIPsafe EULA](https://isipsafe.com/eula).
