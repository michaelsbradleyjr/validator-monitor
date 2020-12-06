#lang racket/base

(require net/http-easy
         racket/cmdline
         racket/date
         racket/string)

(date-display-format 'rfc2822)

(define (log message)
  (displayln (format "~a: ~a"
                     (date->string (current-date) #t)
                     message)))

(define (get-previous-epoch)
  (log "Fetching previous epoch number")
  (let* ([res (response-json (get "https://beaconcha.in/api/v1/epoch/latest"))]
         [latest-epoch (foldl (λ (key hash) (hash-ref hash key))
                              res
                              '(data epoch))])
    (- latest-epoch 1)))

(define (get-missed-attestations epoch validators)
  (log "Checking for missed attestations")
  (let* ([res (response-json (get (format "https://beaconcha.in/api/v1/validator/~a/attestations"
                                          (string-join validators ","))))]
         [attestations (hash-ref res 'data)])
    (foldr (λ (att result)
             (if (and (equal? (hash-ref att 'epoch) epoch)
                      (not (equal? (hash-ref att 'status) 1)))
                 (cons (cons (hash-ref att 'validatorindex)
                             (hash-ref att 'attesterslot))
                       result)
                 result))
           '()
           attestations)))

(define (get-failed-proposals epoch validators)
  (log "Checking for failed block proposals")
  (let* ([res (response-json (get (format "https://beaconcha.in/api/v1/validator/~a/proposals"
                                          (string-join validators ","))))]
         [data (hash-ref res 'data)]
         [proposals (if (list? data) data (list data))])
    (foldr (λ (pro result)
             (if (and (equal? (hash-ref pro 'epoch) epoch)
                      (not (equal? (hash-ref pro 'status) "1")))
                 (cons (cons (hash-ref pro 'proposer)
                             (hash-ref pro 'slot))
                       result)
                 result))
           '()
           proposals)))

(define (telegram-send message chat-id telegram-key)
  (post (format "https://api.telegram.org/bot~a/sendMessage"
                telegram-key)
        #:json (hasheq 'chat_id chat-id
                       'disable_web_page_preview 1
                       'text message
                       'parse_mode "MarkdownV2")))

(define missed-message "Validator ~a missed an attestation at slot ~a in epoch ~a")

(define missed-message-telegram "⚠️ Validator [~a](https://beaconcha.in/validator/~a#attestations) missed an attestation at slot [~a](https://beaconcha.in/block/~a) in epoch [~a](https://beaconcha.in/epoch/~a)")

(define failed-message "Validator ~a failed to make a block proposal at slot ~a in epoch ~a")

(define failed-message-telegram "💥 Validator [~a](https://beaconcha.in/validator/~a#blocks) failed to make a block proposal at slot [~a](https://beaconcha.in/block/~a) in epoch [~a](https://beaconcha.in/epoch/~a)")

(define (monitor validators chat-id telegram-key)
  (let* ([epoch (get-previous-epoch)]
         [missed-attestations (get-missed-attestations epoch validators)]
         [failed-proposals (get-failed-proposals epoch validators)]
         [send (λ (validator-slot-pair console-message telegram-message)
                 (let* ([validator (car validator-slot-pair)]
                        [slot (cdr validator-slot-pair)]
                        [console-message (format console-message
                                                 validator
                                                 slot
                                                 epoch)]
                        [telegram-message (format telegram-message
                                                  validator validator
                                                  slot slot
                                                  epoch epoch)])
                   (log console-message)
                   (telegram-send telegram-message
                                  chat-id
                                  telegram-key)))])
    (if (or (not (equal? missed-attestations '()))
            (not (equal? failed-proposals '())))
        (begin
          (log "Sending telegram messages")
          (for-each (λ (pair) (send pair
                                    missed-message
                                    missed-message-telegram))
                    missed-attestations)
          (for-each (λ (pair) (send pair
                                    failed-message
                                    failed-message-telegram))
                    failed-proposals))
        (log "Nothing to report"))))

(define chat-id (make-parameter ""))
(define telegram-key (make-parameter ""))
(define forever (make-parameter #f))
(define line-buffering (make-parameter #f))

(command-line
 #:program "monitor"
 #:usage-help "for <validators> supply one or more validator indices separated by spaces"
 #:once-each
 [("--chat-id") id ; takes one argument
  "(required) id of telegram chat between yourself and your bot"
  (chat-id id)]
 [("--telegram-key") key ; takes one argument
  "(required) api key for your telegram bot"
  (telegram-key key)]
 [("--forever") "monitor every 6 minutes indefinitely"
  (forever #t)]
 [("--line") "enable line buffering (enabled by default when attached to terminal)"
  (line-buffering #t)]
 #:args validators ; one or more validator indices separated by spaces
 (cond
  [(equal? (chat-id) "")
   (error "Error: --chat-id was not supplied or was empty")]
  [(equal? (telegram-key) "")
   (error "Error: --telegram-key was not supplied or was empty")]
  [(equal? validators '())
   (error "Error: at least one validator index must be supplied")])
 (let ([run-monitor (λ () (monitor validators (chat-id) (telegram-key)))])
   (when (line-buffering) (file-stream-buffer-mode (current-output-port) 'line))
   (log "Starting monitor")
   (if (forever)
       (let loop () ; run indefinitely
         (thread ; run monitor in a separate thread to minimize timer drift
          ; exceptions representing errors will be caught and displayed without
          ; interrupting the loop
          (λ () (with-handlers ([exn:fail? (λ (v) (displayln v))]) (run-monitor))))
         (sleep 360) ; sleep for 6 minutes before running monitor again
         (loop))
       (begin
         (run-monitor)
         (log "Done")))))
