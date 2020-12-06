# validator-monitor

A tool for monitoring ETH2 Beacon Chain validators.

Relies on the free-tier [Beaconcha.in ETH2 API](https://beaconcha.in/api/v1/docs/index.html)
and the [Telegram Bot API](https://core.telegram.org/bots/api).

## Setup and usage

Install [Racket](https://download.racket-lang.org/) and make its binaries
available on your `PATH`, e.g. on macOS:
```
# one time
$ cd /Applications && ln -s "Racket v7.9" Racket
# in your .bashrc
export PATH="/Applications/Racket/bin:${PATH}"
```

There's a [PPA](https://launchpad.net/~plt/+archive/ubuntu/racket) available if
you're running Ubuntu:
```
# if add-apt-repository is missing install software-properties-common
$ sudo add-apt-repository ppa:plt/racket
$ sudo apt-get update
$ sudo apt-get install racket
```

Install `monitor.rkt`'s one dependency with [`raco`](https://docs.racket-lang.org/raco/):
```
$ raco pkg install http-easy
```

Compile `monitor.rkt` into a standalone `monitor` executable and run it:
```
$ raco exe --orig-exe monitor.rkt
$ ./monitor --chat-id "12345" \
            --telegram-key "11111:abcd" \
            --forever \
            9999 10202
```

Or run it via `racket`:
```
$ racket monitor.rkt --chat-id "12345" \
                     --telegram-key "11111:abcd" \
                     --forever \
                     9999 10202
```

It includes `--help` output:
```
$ ./monitor --help
monitor [ <option> ... ] [<validators>] ...
  for <validators> supply one or more validator indices separated by spaces
 where <option> is one of
  --chat-id <id> : (required) id of telegram chat between yourself and your bot
  --telegram-key <key> : (required) api key for your telegram bot
  --forever : monitor every 6 minutes indefinitely
  --help, -h : Show this help
  -- : Do not treat any remaining argument as a switch (at this level)
 Multiple single-letter switches can be combined after one `-'; for
  example: `-h-' is the same as `-h --'
```

If you're running on Linux you could setup a `systemd` service like this:

In */etc/systemd/system/validator-monitor.service*
```
[Unit]
Description=ETH2 Beacon Chain validator monitor

[Service]
ExecStart=/home/michael/repos/validator-monitor/monitor \
  --chat-id "12345" \
  --telegram-key "11111:abcd" \
  --forever \
  --line \
  9999 10202
StandardOutput=append:/home/michael/repos/validator-monitor/monitor.log
StandardError=append:/home/michael/repos/validator-monitor/monitor.log
User=michael
Group=michael
Restart=always

[Install]
WantedBy=default.target
```
Then run:
```
$ sudo systemctl daemon-reload
$ sudo systemctl enable validator-monitor --now
$ systemctl status validator-monitor
```

The free-tier [Beaconcha.in ETH2 API](https://beaconcha.in/api/v1/docs/index.html)
has a limit of 30000 requests per month. When the monitor is run with
`--forever` it will execute 3 requests every 6 minutes, totaling at most 22320
requests per month, so it should be okay.

## Telegram bot setup

In the Telegram app, create a new bot by sending the `/newbot` command to
*[@BotFather](https://t.me/botfather)*. Provide a name and username for your bot
and you'll receive a key to access the API.

Send a message to your bot in Telegram, and then run this command in a terminal:
```
$ curl "https://api.telegram.org/botYOUR_KEY_GOES_HERE/getUpdates"
```
Extract the chat id from the response. If the response failed or did not
contain a chat id, try again after a couple of minutes.

## Credit

Heavily inspired by a colleague's [related work](https://gist.github.com/richard-ramos/5ae07f56cd5d4e1441e872bf0a60c9b4).
