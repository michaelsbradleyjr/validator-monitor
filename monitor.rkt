#lang racket/base

(require control
         nested-hash
         net/http-easy
         racket/cmdline
         racket/date
         racket/string)

(date-display-format 'rfc2822)

(define (get-previous-epoch)
  (let* ([res (response-json (get "https://beaconcha.in/api/v1/epoch/latest"))]
         [latest-epoch (nested-hash-ref res 'data 'epoch)])
  (- latest-epoch 1)))

(define (get-missed-attestations epoch validators)
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
                       'text message))
  (displayln (format "~a: ~a"
                     (date->string (current-date) #t)
                     message)))

(define missed-message "Validator ~a missed an attestation at slot ~a in epoch ~a")

(define failed-message "Validator ~a failed when making a block proposal at slot ~a in epoch ~a")

(define (monitor validators chat-id telegram-key)
  (let* ([epoch (get-previous-epoch)]
         [send (λ (validator-slot-pair message)
                 (let ([validator (car validator-slot-pair)]
                       [slot (cdr validator-slot-pair)])
                   (telegram-send (format message validator slot epoch)
                                   chat-id
                                   telegram-key)))])
  (for-each (λ (pair) (send pair missed-message))
            (get-missed-attestations epoch validators))
  (for-each (λ (pair) (send pair failed-message))
            (get-failed-proposals epoch validators))))

(define chat-id (make-parameter ""))
(define telegram-key (make-parameter ""))
(define forever (make-parameter #f))

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
   #:args validators ; one or more validator indices separated by spaces
   (cond
    [(equal? (chat-id) "")
     (error "Error: --chat-id was not supplied or was empty")]
    [(equal? (telegram-key) "")
     (error "Error: --telegram-key was not supplied or was empty")]
    [(equal? validators '())
     (error "Error: at least one validator index must be supplied")])
   (let ([run-monitor (λ () (monitor validators (chat-id) (telegram-key)))])
     (if (forever)
         (while #t ; run indefinitely
           ; any exceptions that represent errors will be caught and displayed
           ; then the while loop will continue to run
           (with-handlers ([exn:fail? (λ (v) (displayln v))])
             (run-monitor))
           (sleep 360)) ; sleep for 6 minutes before running monitor again
         (run-monitor))))
