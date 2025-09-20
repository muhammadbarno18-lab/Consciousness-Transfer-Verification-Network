;; Consciousness Pattern Preservation Contract
;; Complete neural network mapping and consciousness pattern preservation during transfer processes

;; Constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-PATTERN-NOT-FOUND (err u101))
(define-constant ERR-PATTERN-ALREADY-EXISTS (err u102))
(define-constant ERR-INVALID-PATTERN-DATA (err u103))
(define-constant ERR-INSUFFICIENT-VERIFICATION (err u104))
(define-constant ERR-PATTERN-EXPIRED (err u105))
(define-constant ERR-ACCESS-DENIED (err u106))
(define-constant ERR-PRESERVATION-FAILED (err u107))
(define-constant ERR-INTEGRITY-CHECK-FAILED (err u108))

(define-constant CONTRACT-OWNER tx-sender)
(define-constant PATTERN-EXPIRY-BLOCKS u144000) ;; ~1000 days in blocks
(define-constant MIN-VERIFICATION-SCORE u95) ;; 95% minimum verification score
(define-constant MAX-PATTERN-SIZE u1000000) ;; Maximum pattern data size

;; Data Variables
(define-data-var next-pattern-id uint u1)
(define-data-var total-patterns-preserved uint u0)
(define-data-var preservation-fee uint u1000) ;; STX amount for preservation
(define-data-var verification-threshold uint u3) ;; Number of verifications required

;; Data Maps
(define-map neural-patterns
  { pattern-id: uint }
  {
    owner: principal,
    pattern-hash: (buff 32),
    pattern-data: (string-ascii 1000000),
    creation-block: uint,
    expiry-block: uint,
    verification-count: uint,
    verification-score: uint,
    is-active: bool,
    metadata: (string-ascii 500)
  }
)

(define-map pattern-access-control
  { pattern-id: uint, accessor: principal }
  {
    access-level: uint, ;; 1=read, 2=verify, 3=admin
    granted-at: uint,
    granted-by: principal
  }
)

(define-map pattern-verifications
  { pattern-id: uint, verifier: principal }
  {
    verification-hash: (buff 32),
    verification-score: uint,
    verified-at: uint,
    verification-notes: (string-ascii 200)
  }
)

(define-map preservation-events
  { event-id: uint }
  {
    pattern-id: uint,
    event-type: (string-ascii 50),
    event-data: (string-ascii 500),
    block-height: uint,
    event-initiator: principal
  }
)

(define-map pattern-integrity-checks
  { pattern-id: uint, check-id: uint }
  {
    check-hash: (buff 32),
    check-result: bool,
    check-timestamp: uint,
    checker: principal
  }
)

;; Public Functions

;; Preserve a new neural pattern
(define-public (preserve-pattern (pattern-data (string-ascii 1000000)) (pattern-hash (buff 32)) (metadata (string-ascii 500)))
  (let (
    (pattern-id (var-get next-pattern-id))
    (current-block stacks-block-height)
    (expiry-block (+ stacks-block-height PATTERN-EXPIRY-BLOCKS))
  )
    (asserts! (>= (len pattern-data) u1) ERR-INVALID-PATTERN-DATA)
    (asserts! (<= (len pattern-data) MAX-PATTERN-SIZE) ERR-INVALID-PATTERN-DATA)
    (asserts! (is-none (map-get? neural-patterns { pattern-id: pattern-id })) ERR-PATTERN-ALREADY-EXISTS)
    
    ;; Store the pattern
    (map-set neural-patterns
      { pattern-id: pattern-id }
      {
        owner: tx-sender,
        pattern-hash: pattern-hash,
        pattern-data: pattern-data,
        creation-block: current-block,
        expiry-block: expiry-block,
        verification-count: u0,
        verification-score: u0,
        is-active: true,
        metadata: metadata
      }
    )
    
    ;; Grant owner full access
    (map-set pattern-access-control
      { pattern-id: pattern-id, accessor: tx-sender }
      {
        access-level: u3,
        granted-at: current-block,
        granted-by: tx-sender
      }
    )
    
    ;; Log preservation event
    (unwrap-panic (log-preservation-event pattern-id "PATTERN_PRESERVED" "New neural pattern preserved"))
    
    ;; Update counters
    (var-set next-pattern-id (+ pattern-id u1))
    (var-set total-patterns-preserved (+ (var-get total-patterns-preserved) u1))
    
    (ok pattern-id)
  )
)

;; Verify a neural pattern
(define-public (verify-pattern (pattern-id uint) (verification-hash (buff 32)) (verification-score uint) (notes (string-ascii 200)))
  (let (
    (pattern (unwrap! (map-get? neural-patterns { pattern-id: pattern-id }) ERR-PATTERN-NOT-FOUND))
    (current-verification-count (get verification-count pattern))
    (new-verification-count (+ current-verification-count u1))
    (current-total-score (get verification-score pattern))
    (new-total-score (+ current-total-score verification-score))
    (new-avg-score (/ new-total-score new-verification-count))
  )
    (asserts! (get is-active pattern) ERR-PATTERN-EXPIRED)
    (asserts! (<= stacks-block-height (get expiry-block pattern)) ERR-PATTERN-EXPIRED)
    (asserts! (>= verification-score u0) ERR-INVALID-PATTERN-DATA)
    (asserts! (<= verification-score u100) ERR-INVALID-PATTERN-DATA)
    
    ;; Check if verifier has access
    (asserts! (>= (get-access-level pattern-id tx-sender) u2) ERR-ACCESS-DENIED)
    
    ;; Record verification
    (map-set pattern-verifications
      { pattern-id: pattern-id, verifier: tx-sender }
      {
        verification-hash: verification-hash,
        verification-score: verification-score,
        verified-at: stacks-block-height,
        verification-notes: notes
      }
    )
    
    ;; Update pattern verification data
    (map-set neural-patterns
      { pattern-id: pattern-id }
      (merge pattern {
        verification-count: new-verification-count,
        verification-score: new-avg-score
      })
    )
    
    ;; Log verification event
    (unwrap-panic (log-preservation-event pattern-id "PATTERN_VERIFIED" notes))
    
    (ok new-avg-score)
  )
)

;; Grant access to a pattern
(define-public (grant-pattern-access (pattern-id uint) (accessor principal) (access-level uint))
  (let (
    (pattern (unwrap! (map-get? neural-patterns { pattern-id: pattern-id }) ERR-PATTERN-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender (get owner pattern)) ERR-NOT-AUTHORIZED)
    (asserts! (>= access-level u1) ERR-INVALID-PATTERN-DATA)
    (asserts! (<= access-level u3) ERR-INVALID-PATTERN-DATA)
    
    (map-set pattern-access-control
      { pattern-id: pattern-id, accessor: accessor }
      {
        access-level: access-level,
        granted-at: stacks-block-height,
        granted-by: tx-sender
      }
    )
    
    (unwrap-panic (log-preservation-event pattern-id "ACCESS_GRANTED" "Access granted to new accessor"))
    
    (ok true)
  )
)

;; Perform integrity check
(define-public (perform-integrity-check (pattern-id uint) (check-hash (buff 32)))
  (let (
    (pattern (unwrap! (map-get? neural-patterns { pattern-id: pattern-id }) ERR-PATTERN-NOT-FOUND))
    (check-id (+ (var-get total-patterns-preserved) pattern-id))
    (integrity-result (is-eq check-hash (get pattern-hash pattern)))
  )
    (asserts! (>= (get-access-level pattern-id tx-sender) u2) ERR-ACCESS-DENIED)
    (asserts! (get is-active pattern) ERR-PATTERN-EXPIRED)
    
    (map-set pattern-integrity-checks
      { pattern-id: pattern-id, check-id: check-id }
      {
        check-hash: check-hash,
        check-result: integrity-result,
        check-timestamp: stacks-block-height,
        checker: tx-sender
      }
    )
    
    (if integrity-result
      (unwrap-panic (log-preservation-event pattern-id "INTEGRITY_CHECK_PASSED" "Pattern integrity verified"))
      (unwrap-panic (log-preservation-event pattern-id "INTEGRITY_CHECK_FAILED" "Pattern integrity check failed"))
    )
    
    (ok integrity-result)
  )
)

;; Deactivate pattern (owner only)
(define-public (deactivate-pattern (pattern-id uint))
  (let (
    (pattern (unwrap! (map-get? neural-patterns { pattern-id: pattern-id }) ERR-PATTERN-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender (get owner pattern)) ERR-NOT-AUTHORIZED)
    
    (map-set neural-patterns
      { pattern-id: pattern-id }
      (merge pattern { is-active: false })
    )
    
    (unwrap-panic (log-preservation-event pattern-id "PATTERN_DEACTIVATED" "Pattern deactivated by owner"))
    
    (ok true)
  )
)

;; Read-Only Functions

;; Get pattern information
(define-read-only (get-pattern-info (pattern-id uint))
  (map-get? neural-patterns { pattern-id: pattern-id })
)

;; Get pattern access level for a user
(define-read-only (get-access-level (pattern-id uint) (accessor principal))
  (match (map-get? pattern-access-control { pattern-id: pattern-id, accessor: accessor })
    access-info (get access-level access-info)
    u0
  )
)

;; Check if pattern is verified (meets threshold)
(define-read-only (is-pattern-verified (pattern-id uint))
  (match (map-get? neural-patterns { pattern-id: pattern-id })
    pattern (and
      (>= (get verification-count pattern) (var-get verification-threshold))
      (>= (get verification-score pattern) MIN-VERIFICATION-SCORE)
    )
    false
  )
)

;; Get verification details
(define-read-only (get-verification-details (pattern-id uint) (verifier principal))
  (map-get? pattern-verifications { pattern-id: pattern-id, verifier: verifier })
)

;; Get integrity check result
(define-read-only (get-integrity-check (pattern-id uint) (check-id uint))
  (map-get? pattern-integrity-checks { pattern-id: pattern-id, check-id: check-id })
)

;; Get total preserved patterns
(define-read-only (get-total-patterns)
  (var-get total-patterns-preserved)
)

;; Get current preservation fee
(define-read-only (get-preservation-fee)
  (var-get preservation-fee)
)

;; Private Functions

;; Log preservation events
(define-private (log-preservation-event (pattern-id uint) (event-type (string-ascii 50)) (event-data (string-ascii 500)))
  (let (
    (event-id (+ (var-get total-patterns-preserved) pattern-id))
  )
    (map-set preservation-events
      { event-id: event-id }
      {
        pattern-id: pattern-id,
        event-type: event-type,
        event-data: event-data,
        block-height: stacks-block-height,
        event-initiator: tx-sender
      }
    )
    (ok event-id)
  )
)

