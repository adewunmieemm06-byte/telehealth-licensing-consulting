;; Telehealth Licensing Consulting Platform
;; Manages provider licenses, applications, renewals, regulatory updates, and compliance monitoring

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-INVALID-STATE (err u400))
(define-constant ERR-NOT-FOUND (err u404))

;; Data structures for licensure management
(define-map licensure-records
  { provider-id: principal, state: (string-ascii 2) }
  {
    license-number: (string-ascii 50),
    issue-date: uint,
    expiration-date: uint,
    status: (string-ascii 20),
    specialty: (string-ascii 100)
  }
)

;; Track applications across states
(define-map application-tracking
  { application-id: uint, state: (string-ascii 2) }
  {
    provider-id: principal,
    submission-date: uint,
    status: (string-ascii 20),
    submission-details: (string-ascii 500),
    approval-date: (optional uint)
  }
)

;; Manage renewal dates and deadlines
(define-map renewal-tracking
  { provider-id: principal, state: (string-ascii 2) }
  {
    last-renewal-date: uint,
    next-renewal-date: uint,
    renewal-window-days: uint,
    renewal-status: (string-ascii 20)
  }
)

;; Post regulatory requirement updates
(define-map regulatory-updates
  { update-id: uint }
  {
    state: (string-ascii 2),
    timestamp: uint,
    requirement-type: (string-ascii 100),
    description: (string-ascii 500),
    effective-date: uint
  }
)

;; Monitor compliance across states
(define-map compliance-monitoring
  { provider-id: principal }
  {
    total-states-licensed: uint,
    compliant-states: uint,
    non-compliant-states: uint,
    last-audit-date: uint,
    compliance-score: uint
  }
)

;; Counter for application IDs
(define-data-var next-application-id uint u1)
(define-data-var next-update-id uint u1)

;; Register a new license
(define-public (register-license (provider-id principal) (state (string-ascii 2)) (license-number (string-ascii 50)) (specialty (string-ascii 100)) (expiration-date uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-set licensure-records
      { provider-id: provider-id, state: state }
      {
        license-number: license-number,
        issue-date: block-height,
        expiration-date: expiration-date,
        status: "active",
        specialty: specialty
      }
    )
    (ok true)
  )
)

;; Submit an application
(define-public (submit-application (provider-id principal) (state (string-ascii 2)) (details (string-ascii 500)))
  (let ((app-id (var-get next-application-id)))
    (begin
      (map-set application-tracking
        { application-id: app-id, state: state }
        {
          provider-id: provider-id,
          submission-date: block-height,
          status: "submitted",
          submission-details: details,
          approval-date: none
        }
      )
      (var-set next-application-id (+ app-id u1))
      (ok app-id)
    )
  )
)

;; Approve an application
(define-public (approve-application (application-id uint) (state (string-ascii 2)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (let ((app (map-get? application-tracking { application-id: application-id, state: state })))
      (match app
        existing-app
        (begin
          (map-set application-tracking
            { application-id: application-id, state: state }
            (merge existing-app {
              status: "approved",
              approval-date: (some block-height)
            })
          )
          (ok true)
        )
        (err ERR-NOT-FOUND)
      )
    )
  )
)

;; Set renewal tracking
(define-public (set-renewal-tracking (provider-id principal) (state (string-ascii 2)) (renewal-window-days uint) (next-renewal-date uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-set renewal-tracking
      { provider-id: provider-id, state: state }
      {
        last-renewal-date: block-height,
        next-renewal-date: next-renewal-date,
        renewal-window-days: renewal-window-days,
        renewal-status: "pending"
      }
    )
    (ok true)
  )
)

;; Post a regulatory update
(define-public (post-regulatory-update (state (string-ascii 2)) (requirement-type (string-ascii 100)) (description (string-ascii 500)) (effective-date uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (let ((update-id (var-get next-update-id)))
      (begin
        (map-set regulatory-updates
          { update-id: update-id }
          {
            state: state,
            timestamp: block-height,
            requirement-type: requirement-type,
            description: description,
            effective-date: effective-date
          }
        )
        (var-set next-update-id (+ update-id u1))
        (ok update-id)
      )
    )
  )
)

;; Update compliance monitoring
(define-public (update-compliance (provider-id principal) (compliant-states uint) (non-compliant-states uint) (score uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-set compliance-monitoring
      { provider-id: provider-id }
      {
        total-states-licensed: (+ compliant-states non-compliant-states),
        compliant-states: compliant-states,
        non-compliant-states: non-compliant-states,
        last-audit-date: block-height,
        compliance-score: score
      }
    )
    (ok true)
  )
)

;; Get license info
(define-read-only (get-license (provider-id principal) (state (string-ascii 2)))
  (map-get? licensure-records { provider-id: provider-id, state: state })
)

;; Get renewal info
(define-read-only (get-renewal-info (provider-id principal) (state (string-ascii 2)))
  (map-get? renewal-tracking { provider-id: provider-id, state: state })
)

;; Get compliance info
(define-read-only (get-compliance-info (provider-id principal))
  (map-get? compliance-monitoring { provider-id: provider-id })
)
