;; Identity Continuity Validation Contract
;; Automated verification of consciousness continuity and identity preservation after transfer

;; Constants
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-IDENTITY-NOT-FOUND (err u201))
(define-constant ERR-INVALID-VALIDATION-DATA (err u202))
(define-constant ERR-CONTINUITY-VERIFICATION-FAILED (err u203))
(define-constant ERR-IDENTITY-ALREADY-EXISTS (err u204))
(define-constant ERR-TRANSFER-NOT-FOUND (err u205))
(define-constant ERR-ACCESS-DENIED (err u206))
(define-constant ERR-VALIDATION-EXPIRED (err u207))
(define-constant ERR-INSUFFICIENT-METRICS (err u208))
(define-constant ERR-TRANSFER-INCOMPLETE (err u209))

(define-constant CONTRACT-OWNER tx-sender)
(define-constant MIN-CONTINUITY-SCORE u85) ;; 85% minimum continuity score
(define-constant VALIDATION-EXPIRY-BLOCKS u144000) ;; ~1000 days
(define-constant MAX-IDENTITY-DATA-SIZE u500000) ;; Maximum identity data size
(define-constant REQUIRED-VALIDATORS u5) ;; Number of validators required

;; Data Variables
(define-data-var next-identity-id uint u1)
(define-data-var next-transfer-id uint u1)
(define-data-var total-identities uint u0)
(define-data-var total-transfers uint u0)
(define-data-var validation-fee uint u500) ;; STX amount for validation
(define-data-var continuity-threshold uint u85) ;; Minimum continuity score

;; Data Maps
(define-map identity-records
  { identity-id: uint }
  {
    owner: principal,
    identity-hash: (buff 32),
    identity-data: (string-ascii 500000),
    baseline-metrics: (string-ascii 1000),
    creation-block: uint,
    last-updated: uint,
    is-active: bool,
    continuity-score: uint,
    validation-count: uint
  }
)

(define-map consciousness-transfers
  { transfer-id: uint }
  {
    source-identity: uint,
    target-identity: uint,
    transfer-initiator: principal,
    transfer-hash: (buff 32),
    pre-transfer-metrics: (string-ascii 1000),
    post-transfer-metrics: (string-ascii 1000),
    transfer-block: uint,
    validation-block: uint,
    continuity-score: uint,
    is-validated: bool,
    is-successful: bool,
    validator-count: uint
  }
)

(define-map continuity-validations
  { transfer-id: uint, validator: principal }
  {
    validation-hash: (buff 32),
    continuity-assessment: uint,
    identity-preservation-score: uint,
    memory-continuity-score: uint,
    personality-continuity-score: uint,
    validated-at: uint,
    validation-notes: (string-ascii 300)
  }
)

(define-map identity-access-control
  { identity-id: uint, accessor: principal }
  {
    access-level: uint, ;; 1=read, 2=validate, 3=admin
    granted-at: uint,
    granted-by: principal
  }
)

(define-map transfer-events
  { event-id: uint }
  {
    transfer-id: uint,
    event-type: (string-ascii 50),
    event-data: (string-ascii 500),
    block-height: uint,
    event-initiator: principal
  }
)

(define-map identity-metrics
  { identity-id: uint, metric-type: (string-ascii 50) }
  {
    metric-value: uint,
    metric-data: (string-ascii 200),
    measured-at: uint,
    measured-by: principal
  }
)

;; Public Functions

;; Register a new identity for consciousness transfer validation
(define-public (register-identity (identity-data (string-ascii 500000)) (identity-hash (buff 32)) (baseline-metrics (string-ascii 1000)))
  (let (
    (identity-id (var-get next-identity-id))
    (current-block stacks-block-height)
  )
    (asserts! (>= (len identity-data) u1) ERR-INVALID-VALIDATION-DATA)
    (asserts! (<= (len identity-data) MAX-IDENTITY-DATA-SIZE) ERR-INVALID-VALIDATION-DATA)
    (asserts! (is-none (map-get? identity-records { identity-id: identity-id })) ERR-IDENTITY-ALREADY-EXISTS)
    
    ;; Store identity record
    (map-set identity-records
      { identity-id: identity-id }
      {
        owner: tx-sender,
        identity-hash: identity-hash,
        identity-data: identity-data,
        baseline-metrics: baseline-metrics,
        creation-block: current-block,
        last-updated: current-block,
        is-active: true,
        continuity-score: u100, ;; Initial perfect score
        validation-count: u0
      }
    )
    
    ;; Grant owner full access
    (map-set identity-access-control
      { identity-id: identity-id, accessor: tx-sender }
      {
        access-level: u3,
        granted-at: current-block,
        granted-by: tx-sender
      }
    )
    
    ;; Log registration event
    (unwrap-panic (log-transfer-event identity-id "IDENTITY_REGISTERED" "New identity registered for validation"))
    
    ;; Update counters
    (var-set next-identity-id (+ identity-id u1))
    (var-set total-identities (+ (var-get total-identities) u1))
    
    (ok identity-id)
  )
)

;; Initiate consciousness transfer validation
(define-public (initiate-transfer-validation (source-identity-id uint) (target-identity-id uint) (transfer-hash (buff 32)) (pre-metrics (string-ascii 1000)) (post-metrics (string-ascii 1000)))
  (let (
    (transfer-id (var-get next-transfer-id))
    (source-identity (unwrap! (map-get? identity-records { identity-id: source-identity-id }) ERR-IDENTITY-NOT-FOUND))
    (target-identity (unwrap! (map-get? identity-records { identity-id: target-identity-id }) ERR-IDENTITY-NOT-FOUND))
  )
    (asserts! (get is-active source-identity) ERR-IDENTITY-NOT-FOUND)
    (asserts! (get is-active target-identity) ERR-IDENTITY-NOT-FOUND)
    (asserts! (>= (get-identity-access-level source-identity-id tx-sender) u2) ERR-ACCESS-DENIED)
    
    ;; Create transfer record
    (map-set consciousness-transfers
      { transfer-id: transfer-id }
      {
        source-identity: source-identity-id,
        target-identity: target-identity-id,
        transfer-initiator: tx-sender,
        transfer-hash: transfer-hash,
        pre-transfer-metrics: pre-metrics,
        post-transfer-metrics: post-metrics,
        transfer-block: stacks-block-height,
        validation-block: u0,
        continuity-score: u0,
        is-validated: false,
        is-successful: false,
        validator-count: u0
      }
    )
    
    ;; Log transfer initiation
    (unwrap-panic (log-transfer-event transfer-id "TRANSFER_INITIATED" "Consciousness transfer validation initiated"))
    
    ;; Update counters
    (var-set next-transfer-id (+ transfer-id u1))
    (var-set total-transfers (+ (var-get total-transfers) u1))
    
    (ok transfer-id)
  )
)

;; Validate consciousness continuity after transfer
(define-public (validate-continuity (transfer-id uint) (validation-hash (buff 32)) (identity-score uint) (memory-score uint) (personality-score uint) (notes (string-ascii 300)))
  (let (
    (transfer (unwrap! (map-get? consciousness-transfers { transfer-id: transfer-id }) ERR-TRANSFER-NOT-FOUND))
    (overall-score (/ (+ identity-score memory-score personality-score) u3))
    (current-validators (get validator-count transfer))
    (new-validator-count (+ current-validators u1))
    (current-total-score (get continuity-score transfer))
    (new-total-score (+ current-total-score overall-score))
    (new-avg-score (if (> new-validator-count u0) (/ new-total-score new-validator-count) u0))
  )
    (asserts! (>= overall-score u0) ERR-INVALID-VALIDATION-DATA)
    (asserts! (<= overall-score u100) ERR-INVALID-VALIDATION-DATA)
    (asserts! (<= identity-score u100) ERR-INVALID-VALIDATION-DATA)
    (asserts! (<= memory-score u100) ERR-INVALID-VALIDATION-DATA)
    (asserts! (<= personality-score u100) ERR-INVALID-VALIDATION-DATA)
    
    ;; Record validation
    (map-set continuity-validations
      { transfer-id: transfer-id, validator: tx-sender }
      {
        validation-hash: validation-hash,
        continuity-assessment: overall-score,
        identity-preservation-score: identity-score,
        memory-continuity-score: memory-score,
        personality-continuity-score: personality-score,
        validated-at: stacks-block-height,
        validation-notes: notes
      }
    )
    
    ;; Update transfer record
    (map-set consciousness-transfers
      { transfer-id: transfer-id }
      (merge transfer {
        validator-count: new-validator-count,
        continuity-score: new-avg-score,
        validation-block: stacks-block-height,
        is-validated: (>= new-validator-count REQUIRED-VALIDATORS),
        is-successful: (and (>= new-validator-count REQUIRED-VALIDATORS) (>= new-avg-score (var-get continuity-threshold)))
      })
    )
    
    ;; Log validation event
    (unwrap-panic (log-transfer-event transfer-id "CONTINUITY_VALIDATED" notes))
    
    (ok new-avg-score)
  )
)

;; Update identity metrics
(define-public (update-identity-metrics (identity-id uint) (metric-type (string-ascii 50)) (metric-value uint) (metric-data (string-ascii 200)))
  (let (
    (identity (unwrap! (map-get? identity-records { identity-id: identity-id }) ERR-IDENTITY-NOT-FOUND))
  )
    (asserts! (>= (get-identity-access-level identity-id tx-sender) u2) ERR-ACCESS-DENIED)
    (asserts! (get is-active identity) ERR-IDENTITY-NOT-FOUND)
    
    (map-set identity-metrics
      { identity-id: identity-id, metric-type: metric-type }
      {
        metric-value: metric-value,
        metric-data: metric-data,
        measured-at: stacks-block-height,
        measured-by: tx-sender
      }
    )
    
    ;; Update identity last-updated timestamp
    (map-set identity-records
      { identity-id: identity-id }
      (merge identity { last-updated: stacks-block-height })
    )
    
    (unwrap-panic (log-transfer-event identity-id "METRICS_UPDATED" metric-data))
    
    (ok true)
  )
)

;; Grant access to identity validation
(define-public (grant-identity-access (identity-id uint) (accessor principal) (access-level uint))
  (let (
    (identity (unwrap! (map-get? identity-records { identity-id: identity-id }) ERR-IDENTITY-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender (get owner identity)) ERR-NOT-AUTHORIZED)
    (asserts! (>= access-level u1) ERR-INVALID-VALIDATION-DATA)
    (asserts! (<= access-level u3) ERR-INVALID-VALIDATION-DATA)
    
    (map-set identity-access-control
      { identity-id: identity-id, accessor: accessor }
      {
        access-level: access-level,
        granted-at: stacks-block-height,
        granted-by: tx-sender
      }
    )
    
    (unwrap-panic (log-transfer-event identity-id "ACCESS_GRANTED" "Identity access granted"))
    
    (ok true)
  )
)

;; Deactivate identity (owner only)
(define-public (deactivate-identity (identity-id uint))
  (let (
    (identity (unwrap! (map-get? identity-records { identity-id: identity-id }) ERR-IDENTITY-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender (get owner identity)) ERR-NOT-AUTHORIZED)
    
    (map-set identity-records
      { identity-id: identity-id }
      (merge identity { is-active: false })
    )
    
    (unwrap-panic (log-transfer-event identity-id "IDENTITY_DEACTIVATED" "Identity deactivated by owner"))
    
    (ok true)
  )
)

;; Read-Only Functions

;; Get identity information
(define-read-only (get-identity-info (identity-id uint))
  (map-get? identity-records { identity-id: identity-id })
)

;; Get transfer information
(define-read-only (get-transfer-info (transfer-id uint))
  (map-get? consciousness-transfers { transfer-id: transfer-id })
)

;; Get identity access level
(define-read-only (get-identity-access-level (identity-id uint) (accessor principal))
  (match (map-get? identity-access-control { identity-id: identity-id, accessor: accessor })
    access-info (get access-level access-info)
    u0
  )
)

;; Check if transfer is successfully validated
(define-read-only (is-transfer-successful (transfer-id uint))
  (match (map-get? consciousness-transfers { transfer-id: transfer-id })
    transfer (get is-successful transfer)
    false
  )
)

;; Get validation details
(define-read-only (get-validation-details (transfer-id uint) (validator principal))
  (map-get? continuity-validations { transfer-id: transfer-id, validator: validator })
)

;; Get identity metrics
(define-read-only (get-identity-metrics (identity-id uint) (metric-type (string-ascii 50)))
  (map-get? identity-metrics { identity-id: identity-id, metric-type: metric-type })
)

;; Get total identities
(define-read-only (get-total-identities)
  (var-get total-identities)
)

;; Get total transfers
(define-read-only (get-total-transfers)
  (var-get total-transfers)
)

;; Get validation fee
(define-read-only (get-validation-fee)
  (var-get validation-fee)
)

;; Private Functions

;; Log transfer events
(define-private (log-transfer-event (related-id uint) (event-type (string-ascii 50)) (event-data (string-ascii 500)))
  (let (
    (event-id (+ (var-get total-transfers) related-id))
  )
    (map-set transfer-events
      { event-id: event-id }
      {
        transfer-id: related-id,
        event-type: event-type,
        event-data: event-data,
        block-height: stacks-block-height,
        event-initiator: tx-sender
      }
    )
    (ok event-id)
  )
)

