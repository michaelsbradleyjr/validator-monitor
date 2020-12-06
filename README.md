# How to use it?

Install [Racket](https://download.racket-lang.org/) and make its binaries
available on your `PATH`, e.g. on macOS:
```
# one time
$ cd /Applications && ln -s "Racket v7.9" Racket
# in your .bashrc
export PATH=/Applications/Racket/bin:$PATH
```

There's a [PPA](https://launchpad.net/~plt/+archive/ubuntu/racket) available if
you're running Ubuntu:
```
$ sudo add-apt-repository ppa:plt/racket
$ sudo apt-get update
$ sudo apt-get install racket
```

Install `monitor.rkt`'s dependencies with `raco`:
```
$ raco pkg install control http-easy nested-hash
```

Compile into a standalone `monitor` executable:
```
$ raco exe --orig-exe monitor.rkt
$ ./monitor --chat-id "12345" \
            --telegram-key "12345:abcd" \
            --forever \
            987 654 321
```

Or run it via `racket`:
```
$ racket monitor.rkt --chat-id "12345" \
                     --telegram-key "12345:abcd" \
                     --forever \
                     987 654 321
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
  --telegram-key "12345:abcd" \
  --forever \
  987 654 321
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
