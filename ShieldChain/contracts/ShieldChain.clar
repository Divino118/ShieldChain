;; ShieldChain: Social Recovery Wallet

(define-trait token-interface
  (
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))
    (get-balance (principal) (response uint uint))
  )
)

;; Error codes
(define-constant ACCESS_DENIED (err u100))
(define-constant SETUP_ALREADY_COMPLETE (err u101))
(define-constant SETUP_INCOMPLETE (err u102))
(define-constant PROTECTOR_DUPLICATE (err u103))
(define-constant PROTECTOR_NOT_FOUND (err u104))
(define-constant RESCUE_ALREADY_ACTIVE (err u105))
(define-constant NO_RESCUE_ACTIVE (err u106))
(define-constant DUPLICATE_ENDORSEMENT (err u107))
(define-constant ENDORSEMENT_THRESHOLD_UNMET (err u108))
(define-constant RESCUE_TIMEOUT (err u109))
(define-constant BALANCE_TOO_LOW (err u110))
(define-constant INVALID_RATIO (err u111))
(define-constant INVALID_CONTROLLER (err u112))
(define-constant INVALID_TOKEN (err u113))

;; Data variables
(define-data-var account-controller principal tx-sender)
(define-data-var setup-complete bool false)
(define-map protector-registry principal bool)
(define-data-var protector-total uint u0)
(define-data-var consensus-ratio uint u51)

(define-data-var rescue-mode bool false)
(define-data-var initiator (optional principal) none)
(define-data-var target-controller (optional principal) none)
(define-data-var rescue-deadline uint u0)
(define-map endorsements principal bool)
(define-data-var endorsement-total uint u0)

;; Whitelisted tokens - store by principal address instead of trait reference
(define-map allowed-tokens principal bool)

(define-constant DAY_SECONDS u86400)
(define-constant RESCUE_WINDOW_DAYS u7)

;; Helper functions for validating inputs
(define-private (is-valid-controller (controller principal))
  (and 
    (not (is-eq controller 'SP000000000000000000002Q6VF78)) ;; Not burn address
    (not (is-eq controller 'ST000000000000000000002AMW42H)) ;; Not pox address
    true))

;; Helper function to validate token contracts
(define-private (is-valid-token (token-contract principal))
  (and
    ;; Check that it's not a system address
    (not (is-eq token-contract 'SP000000000000000000002Q6VF78)) ;; Not burn address
    (not (is-eq token-contract 'ST000000000000000000002AMW42H)) ;; Not pox address
    ;; Additional safety check
    (not (is-eq token-contract (var-get account-controller)))
    true))

;; Read-only functions
(define-read-only (is-controller)
  (is-eq tx-sender (var-get account-controller)))

(define-read-only (is-protector (protector-address principal))
  (default-to false (map-get? protector-registry protector-address)))

(define-read-only (get-consensus-ratio)
  (var-get consensus-ratio))

(define-read-only (get-rescue-details)
  {
    active: (var-get rescue-mode),
    starter: (var-get initiator),
    new-controller: (var-get target-controller),
    deadline: (var-get rescue-deadline),
    current-votes: (var-get endorsement-total),
    required-votes: (calculate-vote-requirement)
  })

(define-read-only (calculate-vote-requirement)
  (let 
    (
      (members (var-get protector-total))
      (ratio (var-get consensus-ratio))
    )
    (if (is-eq members u0)
      u0
      (let
        (
          (needed-raw (/ (* members ratio) u100))
          (has-fraction (> (* needed-raw u100) (* members ratio)))
        )
        (if has-fraction
          (+ needed-raw u1)
          needed-raw
        )
      )
    )
  ))

(define-read-only (get-protector-count)
  (ok (var-get protector-total)))

(define-read-only (has-endorsed (protector-address principal))
  (default-to false (map-get? endorsements protector-address)))

(define-read-only (is-token-allowed (token-contract principal))
  (default-to false (map-get? allowed-tokens token-contract)))

;; Public functions
(define-public (setup (initial-controller principal) (initial-ratio uint))
  (begin
    (asserts! (not (var-get setup-complete)) SETUP_ALREADY_COMPLETE)
    (asserts! (and (>= initial-ratio u1) (<= initial-ratio u100)) INVALID_RATIO)
    (asserts! (is-valid-controller initial-controller) INVALID_CONTROLLER)
    (var-set account-controller initial-controller)
    (var-set consensus-ratio initial-ratio)
    (var-set setup-complete true)
    (ok true)))

(define-public (register-protector (protector-address principal))
  (begin
    (asserts! (var-get setup-complete) SETUP_INCOMPLETE)
    (asserts! (is-controller) ACCESS_DENIED)
    (asserts! (not (is-protector protector-address)) PROTECTOR_DUPLICATE)
    (map-set protector-registry protector-address true)
    (var-set protector-total (+ (var-get protector-total) u1))
    (ok true)))

(define-public (unregister-protector (protector-address principal))
  (begin
    (asserts! (var-get setup-complete) SETUP_INCOMPLETE)
    (asserts! (is-controller) ACCESS_DENIED)
    (asserts! (not (var-get rescue-mode)) RESCUE_ALREADY_ACTIVE)
    (asserts! (is-protector protector-address) PROTECTOR_NOT_FOUND)
    (map-delete protector-registry protector-address)
    (var-set protector-total (- (var-get protector-total) u1))
    (ok true)))

(define-public (update-consensus-ratio (new-ratio uint))
  (begin
    (asserts! (var-get setup-complete) SETUP_INCOMPLETE)
    (asserts! (is-controller) ACCESS_DENIED)
    (asserts! (and (>= new-ratio u1) (<= new-ratio u100)) INVALID_RATIO)
    (var-set consensus-ratio new-ratio)
    (ok true)))

(define-public (start-rescue (new-controller principal))
  (begin
    (asserts! (var-get setup-complete) SETUP_INCOMPLETE)
    (asserts! (is-protector tx-sender) ACCESS_DENIED)
    (asserts! (not (var-get rescue-mode)) RESCUE_ALREADY_ACTIVE)
    (asserts! (is-valid-controller new-controller) INVALID_CONTROLLER)
    (var-set rescue-mode true)
    (var-set initiator (some tx-sender))
    (var-set target-controller (some new-controller))
    (var-set rescue-deadline (+ stacks-block-height (* RESCUE_WINDOW_DAYS DAY_SECONDS)))
    (var-set endorsement-total u0)
    (map-set endorsements tx-sender true)
    (var-set endorsement-total (+ (var-get endorsement-total) u1))
    (ok true)))

(define-public (endorse-rescue)
  (begin
    (asserts! (var-get setup-complete) SETUP_INCOMPLETE)
    (asserts! (is-protector tx-sender) ACCESS_DENIED)
    (asserts! (var-get rescue-mode) NO_RESCUE_ACTIVE)
    (asserts! (not (has-endorsed tx-sender)) DUPLICATE_ENDORSEMENT)
    (asserts! (<= stacks-block-height (var-get rescue-deadline)) RESCUE_TIMEOUT)
    (map-set endorsements tx-sender true)
    (var-set endorsement-total (+ (var-get endorsement-total) u1))
    (ok true)))

(define-public (complete-rescue)
  (begin
    (asserts! (var-get setup-complete) SETUP_INCOMPLETE)
    (asserts! (var-get rescue-mode) NO_RESCUE_ACTIVE)
    (asserts! (<= stacks-block-height (var-get rescue-deadline)) RESCUE_TIMEOUT)
    (asserts! (>= (var-get endorsement-total) (calculate-vote-requirement)) ENDORSEMENT_THRESHOLD_UNMET)
    (let ((new-controller (unwrap! (var-get target-controller) SETUP_INCOMPLETE)))
      (var-set account-controller new-controller)
      (var-set rescue-mode false)
      (var-set initiator none)
      (var-set target-controller none)
      (var-set endorsement-total u0)
    )
    (ok true)))

(define-public (abort-rescue)
  (begin
    (asserts! (var-get setup-complete) SETUP_INCOMPLETE)
    (asserts! (is-controller) ACCESS_DENIED)
    (asserts! (var-get rescue-mode) NO_RESCUE_ACTIVE)
    (var-set rescue-mode false)
    (var-set initiator none)
    (var-set target-controller none)
    (var-set endorsement-total u0)
    (ok true)))

(define-public (register-token (token-contract principal))
  (begin
    (asserts! (var-get setup-complete) SETUP_INCOMPLETE)
    (asserts! (is-controller) ACCESS_DENIED)
    ;; Validate token contract before registering
    (asserts! (is-valid-token token-contract) INVALID_TOKEN)
    (map-set allowed-tokens token-contract true)
    (ok true)))

(define-public (unregister-token (token-contract principal))
  (begin
    (asserts! (var-get setup-complete) SETUP_INCOMPLETE)
    (asserts! (is-controller) ACCESS_DENIED)
    ;; Ensure the token exists in our allowed list before trying to remove it
    (asserts! (is-token-allowed token-contract) INVALID_TOKEN)
    (map-delete allowed-tokens token-contract)
    (ok true)))

(define-public (send-token (token-contract <token-interface>) (recipient principal) (value uint))
  (begin
    (asserts! (var-get setup-complete) SETUP_INCOMPLETE)
    (asserts! (is-controller) ACCESS_DENIED)
    (asserts! (is-token-allowed (contract-of token-contract)) INVALID_TOKEN)
    (contract-call? token-contract transfer value tx-sender recipient none)))

(define-public (send-stx (recipient principal) (value uint))
  (begin
    (asserts! (var-get setup-complete) SETUP_INCOMPLETE)
    (asserts! (is-controller) ACCESS_DENIED)
    (asserts! (>= (stx-get-balance tx-sender) value) BALANCE_TOO_LOW)
    (stx-transfer? value tx-sender recipient)))

(define-read-only (get-controller)
  (ok (var-get account-controller)))