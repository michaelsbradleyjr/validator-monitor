# How to use it?

Install [Racket](https://download.racket-lang.org/) and make its binaries
available on your `PATH`, e.g. on macOS:
```
# one time
$ cd /Applications && ln -s "Racket v7.9" Racket
# in your .bashrc
export PATH=/Applications/Racket/bin:$PATH
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
