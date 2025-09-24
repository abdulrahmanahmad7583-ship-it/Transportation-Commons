;; Mobility Justice Framework Contract
;; A comprehensive system for ensuring equitable access to transportation
;; resources, promoting social justice, and managing community accessibility needs

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only u200)
(define-constant err-unauthorized u201)
(define-constant err-invalid-request u202)
(define-constant err-insufficient-funds u203)
(define-constant err-already-exists u204)
(define-constant err-not-found u205)
(define-constant err-invalid-status u206)
(define-constant err-quota-exceeded u207)
(define-constant err-assessment-pending u208)
(define-constant err-eligibility-failed u209)

;; Data Variables
(define-data-var assistance-request-counter uint u0)
(define-data-var advocacy-case-counter uint u0)
(define-data-var total-assistance-fund uint u1000000) ;; Initial community fund
(define-data-var total-requests-processed uint u0)
(define-data-var total-advocacy-cases uint u0)
(define-data-var emergency-response-active bool false)
(define-data-var community-engagement-score uint u0)

;; Data Maps
;; User equity profiles and needs assessment
(define-map equity-profiles
  { user: principal }
  {
    mobility-needs-level: uint, ;; 1-5 scale (5 = highest need)
    income-bracket: uint,       ;; 1-5 scale (1 = lowest income)
    accessibility-requirements: (string-ascii 100),
    geographic-barriers: (string-ascii 100),
    assistance-received: uint,
    verified-status: bool,
    assessment-date: uint,
    priority-score: uint
  }
)

;; Assistance requests for transportation equity
(define-map assistance-requests
  { request-id: uint }
  {
    requester: principal,
    request-type: (string-ascii 50), ;; "emergency", "subsidy", "accessibility", "education"
    description: (string-ascii 200),
    amount-requested: uint,
    urgency-level: uint,    ;; 1-5 scale
    status: (string-ascii 20),
    created-at: uint,
    reviewed-at: uint,
    approved-by: (optional principal)
  }
)

;; Advocacy cases for systemic transportation issues
(define-map advocacy-cases
  { case-id: uint }
  {
    reporter: principal,
    issue-type: (string-ascii 50),
    affected-community: (string-ascii 100),
    description: (string-ascii 300),
    evidence-links: (string-ascii 200),
    priority-level: uint,
    status: (string-ascii 30),
    supporters: uint,
    created-at: uint,
    last-updated: uint
  }
)

;; Community resource allocation tracking
(define-map resource-allocations
  { allocation-id: uint }
  {
    resource-type: (string-ascii 50),
    target-demographic: (string-ascii 100),
    allocated-amount: uint,
    utilization-rate: uint,
    effectiveness-score: uint,
    allocation-date: uint,
    review-date: uint
  }
)

;; Accessibility compliance tracking
(define-map accessibility-assessments
  { assessment-id: uint }
  {
    assessed-entity: (string-ascii 100),
    assessor: principal,
    compliance-score: uint,
    barriers-identified: (string-ascii 200),
    recommendations: (string-ascii 200),
    follow-up-required: bool,
    assessment-date: uint,
    next-review-date: uint
  }
)

;; Community feedback and engagement
(define-map community-feedback
  { feedback-id: uint }
  {
    contributor: principal,
    feedback-type: (string-ascii 30),
    content: (string-ascii 300),
    relevance-score: uint,
    addressed: bool,
    created-at: uint,
    admin-response: (optional (string-ascii 200))
  }
)

;; Public Functions

;; Submit request for transportation assistance
(define-public (submit-assistance-request (request-type (string-ascii 50))
                                        (description (string-ascii 200))
                                        (amount-requested uint)
                                        (urgency-level uint))
  (let (
    (new-request-id (+ (var-get assistance-request-counter) u1))
    (current-block stacks-block-height)
    (user-profile (default-to 
      { mobility-needs-level: u3, income-bracket: u3, accessibility-requirements: "", 
        geographic-barriers: "", assistance-received: u0, verified-status: false,
        assessment-date: u0, priority-score: u0 }
      (map-get? equity-profiles { user: tx-sender })
    ))
  )
    ;; Validate request parameters
    (asserts! (and (> urgency-level u0) (<= urgency-level u5)) (err err-invalid-request))
    (asserts! (> amount-requested u0) (err err-invalid-request))
    ;; Check if user has exceeded assistance quota
    (asserts! (<= (get assistance-received user-profile) u5) (err err-quota-exceeded))
    ;; Create assistance request
    (map-set assistance-requests { request-id: new-request-id }
      {
        requester: tx-sender,
        request-type: request-type,
        description: description,
        amount-requested: amount-requested,
        urgency-level: urgency-level,
        status: "pending",
        created-at: current-block,
        reviewed-at: u0,
        approved-by: none
      }
    )
    ;; Update counters
    (var-set assistance-request-counter new-request-id)
    (var-set total-requests-processed (+ (var-get total-requests-processed) u1))
    (ok new-request-id)
  )
)

;; Create equity profile assessment
(define-public (create-equity-profile (mobility-needs-level uint)
                                    (income-bracket uint)
                                    (accessibility-requirements (string-ascii 100))
                                    (geographic-barriers (string-ascii 100)))
  (let (
    (current-block stacks-block-height)
    (priority-score (calculate-priority-score mobility-needs-level income-bracket))
  )
    ;; Validate input parameters
    (asserts! (and (> mobility-needs-level u0) (<= mobility-needs-level u5)) (err err-invalid-request))
    (asserts! (and (> income-bracket u0) (<= income-bracket u5)) (err err-invalid-request))
    ;; Create or update profile
    (map-set equity-profiles { user: tx-sender }
      {
        mobility-needs-level: mobility-needs-level,
        income-bracket: income-bracket,
        accessibility-requirements: accessibility-requirements,
        geographic-barriers: geographic-barriers,
        assistance-received: u0,
        verified-status: false,
        assessment-date: current-block,
        priority-score: priority-score
      }
    )
    (ok priority-score)
  )
)

;; Report advocacy case for systemic issues
(define-public (report-advocacy-case (issue-type (string-ascii 50))
                                   (affected-community (string-ascii 100))
                                   (description (string-ascii 300))
                                   (evidence-links (string-ascii 200))
                                   (priority-level uint))
  (let (
    (new-case-id (+ (var-get advocacy-case-counter) u1))
    (current-block stacks-block-height)
  )
    ;; Validate parameters
    (asserts! (and (> priority-level u0) (<= priority-level u5)) (err err-invalid-request))
    ;; Create advocacy case
    (map-set advocacy-cases { case-id: new-case-id }
      {
        reporter: tx-sender,
        issue-type: issue-type,
        affected-community: affected-community,
        description: description,
        evidence-links: evidence-links,
        priority-level: priority-level,
        status: "open",
        supporters: u0,
        created-at: current-block,
        last-updated: current-block
      }
    )
    ;; Update counters
    (var-set advocacy-case-counter new-case-id)
    (var-set total-advocacy-cases (+ (var-get total-advocacy-cases) u1))
    (ok new-case-id)
  )
)

;; Support an advocacy case
(define-public (support-advocacy-case (case-id uint))
  (let (
    (advocacy-case (unwrap! (map-get? advocacy-cases { case-id: case-id }) (err err-not-found)))
    (current-block stacks-block-height)
  )
    ;; Verify case exists and is open
    (asserts! (is-eq (get status advocacy-case) "open") (err err-invalid-status))
    ;; Update supporter count
    (map-set advocacy-cases { case-id: case-id }
      (merge advocacy-case {
        supporters: (+ (get supporters advocacy-case) u1),
        last-updated: current-block
      })
    )
    ;; Increase community engagement score
    (var-set community-engagement-score (+ (var-get community-engagement-score) u1))
    (ok true)
  )
)

;; Approve assistance request (admin function)
(define-public (approve-assistance-request (request-id uint))
  (let (
    (request (unwrap! (map-get? assistance-requests { request-id: request-id }) (err err-not-found)))
    (current-fund (var-get total-assistance-fund))
    (current-block stacks-block-height)
    (requester-profile (unwrap! (map-get? equity-profiles { user: (get requester request) }) (err err-not-found)))
  )
    ;; Only contract owner can approve (in real implementation, would be governance)
    (asserts! (is-eq tx-sender contract-owner) (err err-owner-only))
    ;; Check fund availability
    (asserts! (>= current-fund (get amount-requested request)) (err err-insufficient-funds))
    ;; Verify request is pending
    (asserts! (is-eq (get status request) "pending") (err err-invalid-status))
    ;; Update request status
    (map-set assistance-requests { request-id: request-id }
      (merge request {
        status: "approved",
        reviewed-at: current-block,
        approved-by: (some tx-sender)
      })
    )
    ;; Update fund balance
    (var-set total-assistance-fund (- current-fund (get amount-requested request)))
    ;; Update user assistance tracking
    (map-set equity-profiles { user: (get requester request) }
      (merge requester-profile {
        assistance-received: (+ (get assistance-received requester-profile) u1)
      })
    )
    (ok true)
  )
)

;; Conduct accessibility assessment
(define-public (conduct-accessibility-assessment (assessed-entity (string-ascii 100))
                                               (compliance-score uint)
                                               (barriers-identified (string-ascii 200))
                                               (recommendations (string-ascii 200))
                                               (follow-up-required bool))
  (let (
    (assessment-id (+ (var-get advocacy-case-counter) u1)) ;; Reuse counter for simplicity
    (current-block stacks-block-height)
    (next-review (+ current-block u52560)) ;; Approximately 1 year
  )
    ;; Validate compliance score
    (asserts! (and (>= compliance-score u0) (<= compliance-score u100)) (err err-invalid-request))
    ;; Create assessment record
    (map-set accessibility-assessments { assessment-id: assessment-id }
      {
        assessed-entity: assessed-entity,
        assessor: tx-sender,
        compliance-score: compliance-score,
        barriers-identified: barriers-identified,
        recommendations: recommendations,
        follow-up-required: follow-up-required,
        assessment-date: current-block,
        next-review-date: next-review
      }
    )
    (ok assessment-id)
  )
)

;; Submit community feedback
(define-public (submit-community-feedback (feedback-type (string-ascii 30))
                                        (content (string-ascii 300)))
  (let (
    (feedback-id (+ (var-get total-requests-processed) u1)) ;; Reuse counter
    (current-block stacks-block-height)
    (relevance-score (calculate-relevance-score feedback-type))
  )
    ;; Create feedback record
    (map-set community-feedback { feedback-id: feedback-id }
      {
        contributor: tx-sender,
        feedback-type: feedback-type,
        content: content,
        relevance-score: relevance-score,
        addressed: false,
        created-at: current-block,
        admin-response: none
      }
    )
    ;; Update engagement metrics
    (var-set community-engagement-score (+ (var-get community-engagement-score) u2))
    (ok feedback-id)
  )
)

;; Read-only Functions

;; Get equity profile
(define-read-only (get-equity-profile (user principal))
  (map-get? equity-profiles { user: user })
)

;; Get assistance request details
(define-read-only (get-assistance-request (request-id uint))
  (map-get? assistance-requests { request-id: request-id })
)

;; Get advocacy case details
(define-read-only (get-advocacy-case (case-id uint))
  (map-get? advocacy-cases { case-id: case-id })
)

;; Get accessibility assessment
(define-read-only (get-accessibility-assessment (assessment-id uint))
  (map-get? accessibility-assessments { assessment-id: assessment-id })
)

;; Get community feedback
(define-read-only (get-community-feedback (feedback-id uint))
  (map-get? community-feedback { feedback-id: feedback-id })
)

;; Get system statistics
(define-read-only (get-justice-framework-stats)
  {
    total-assistance-fund: (var-get total-assistance-fund),
    total-requests-processed: (var-get total-requests-processed),
    total-advocacy-cases: (var-get total-advocacy-cases),
    community-engagement-score: (var-get community-engagement-score),
    emergency-response-active: (var-get emergency-response-active)
  }
)

;; Check user eligibility for assistance
(define-read-only (check-assistance-eligibility (user principal))
  (match (map-get? equity-profiles { user: user })
    profile 
      {
        eligible: (and 
          (<= (get assistance-received profile) u5)
          (>= (get priority-score profile) u6)
        ),
        priority-score: (get priority-score profile),
        assistance-count: (get assistance-received profile)
      }
    { eligible: false, priority-score: u0, assistance-count: u0 }
  )
)

;; Private Functions

;; Calculate priority score based on needs and income
(define-private (calculate-priority-score (needs-level uint) (income-bracket uint))
  (let (
    (needs-weight (* needs-level u2))
    (income-weight (- u10 income-bracket)) ;; Lower income = higher weight
  )
    (+ needs-weight income-weight)
  )
)

;; Calculate relevance score for feedback
(define-private (calculate-relevance-score (feedback-type (string-ascii 30)))
  (if (or (is-eq feedback-type "barrier-report")
          (is-eq feedback-type "accessibility-issue")
          (is-eq feedback-type "service-gap"))
    u8
    u5
  )
)

;; Validate emergency response criteria
(define-private (is-emergency-response-needed (urgency-level uint) (needs-level uint))
  (and (>= urgency-level u4) (>= needs-level u4))
)
