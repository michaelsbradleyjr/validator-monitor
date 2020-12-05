#lang racket/base

(require nested-hash
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

(define failed-message "Validator ~a failed a block proposal at slot ~a in epoch ~a")

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

(define cli-chat-id (make-parameter ""))
(define cli-telegram-key (make-parameter ""))

(command-line
   #:program "monitor"
   #:once-each
   [("--chat-id") cid "id of the telegram chat between yourself and your bot"
                       (cli-chat-id cid)]
   [("--telegram-key") tkey "api key for your telegram bot"
                       (cli-telegram-key tkey)]
   #:args validators ; one or more validator indices separated by spaces
   (monitor validators (cli-chat-id) (cli-telegram-key)))
