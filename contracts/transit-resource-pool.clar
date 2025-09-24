;; Transit Resource Pool Contract
;; A decentralized system for sharing and managing transportation resources
;; within a community, enabling efficient resource allocation and cooperative mobility

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only u100)
(define-constant err-unauthorized u101)
(define-constant err-invalid-resource u102)
(define-constant err-resource-not-available u103)
(define-constant err-insufficient-balance u104)
(define-constant err-already-exists u105)
(define-constant err-invalid-time u106)
(define-constant err-booking-conflict u107)
(define-constant err-not-found u108)

;; Data Variables
(define-data-var resource-id-counter uint u0)
(define-data-var booking-id-counter uint u0)
(define-data-var total-resources uint u0)
(define-data-var total-bookings uint u0)
(define-data-var emergency-mode bool false)
(define-data-var maintenance-window uint u0)

;; Data Maps
;; Resource management
(define-map resources 
  { resource-id: uint }
  {
    owner: principal,
    resource-type: (string-ascii 50),
    description: (string-ascii 200),
    location: (string-ascii 100),
    capacity: uint,
    hourly-rate: uint,
    availability: bool,
    created-at: uint,
    last-maintained: uint
  }
)

;; User profiles and credits
(define-map user-profiles
  { user: principal }
  {
    credit-balance: uint,
    reputation-score: uint,
    total-bookings: uint,
    joined-at: uint,
    active: bool
  }
)

;; Resource bookings
(define-map bookings
  { booking-id: uint }
  {
    user: principal,
    resource-id: uint,
    start-time: uint,
    end-time: uint,
    total-cost: uint,
    status: (string-ascii 20),
    created-at: uint
  }
)

;; Resource availability tracking
(define-map resource-schedule
  { resource-id: uint, time-slot: uint }
  { booked: bool, booking-id: uint }
)

;; Community contributions tracking
(define-map contributions
  { user: principal }
  {
    total-contributed: uint,
    resources-shared: uint,
    community-score: uint,
    last-contribution: uint
  }
)

;; Public Functions

;; Register a new transportation resource
(define-public (register-resource (resource-type (string-ascii 50)) 
                                 (description (string-ascii 200))
                                 (location (string-ascii 100))
                                 (capacity uint)
                                 (hourly-rate uint))
  (let (
    (new-resource-id (+ (var-get resource-id-counter) u1))
    (current-block stacks-block-height)
  )
    ;; Initialize user profile if not exists
    (match (map-get? user-profiles { user: tx-sender })
      existing-profile true
      (map-set user-profiles { user: tx-sender }
        {
          credit-balance: u100,
          reputation-score: u50,
          total-bookings: u0,
          joined-at: current-block,
          active: true
        }
      )
    )
    ;; Create the resource
    (map-set resources { resource-id: new-resource-id }
      {
        owner: tx-sender,
        resource-type: resource-type,
        description: description,
        location: location,
        capacity: capacity,
        hourly-rate: hourly-rate,
        availability: true,
        created-at: current-block,
        last-maintained: current-block
      }
    )
    ;; Update counters and contribution tracking
    (var-set resource-id-counter new-resource-id)
    (var-set total-resources (+ (var-get total-resources) u1))
    (match (map-get? contributions { user: tx-sender })
      existing-contrib 
        (map-set contributions { user: tx-sender }
          (merge existing-contrib {
            resources-shared: (+ (get resources-shared existing-contrib) u1),
            community-score: (+ (get community-score existing-contrib) u10),
            last-contribution: current-block
          })
        )
      (map-set contributions { user: tx-sender }
        {
          total-contributed: u0,
          resources-shared: u1,
          community-score: u10,
          last-contribution: current-block
        }
      )
    )
    (ok new-resource-id)
  )
)

;; Book a transportation resource
(define-public (book-resource (resource-id uint) (start-time uint) (end-time uint))
  (let (
    (resource (unwrap! (map-get? resources { resource-id: resource-id }) (err err-not-found)))
    (user-profile (unwrap! (map-get? user-profiles { user: tx-sender }) (err err-unauthorized)))
    (booking-duration (- end-time start-time))
    (total-cost (* booking-duration (get hourly-rate resource)))
    (new-booking-id (+ (var-get booking-id-counter) u1))
    (current-block stacks-block-height)
  )
    ;; Validate booking
    (asserts! (get availability resource) (err err-resource-not-available))
    (asserts! (get active user-profile) (err err-unauthorized))
    (asserts! (>= (get credit-balance user-profile) total-cost) (err err-insufficient-balance))
    (asserts! (> end-time start-time) (err err-invalid-time))
    (asserts! (>= start-time current-block) (err err-invalid-time))
    ;; Check for scheduling conflicts
    (asserts! (is-time-slot-available resource-id start-time end-time) (err err-booking-conflict))
    ;; Create booking
    (map-set bookings { booking-id: new-booking-id }
      {
        user: tx-sender,
        resource-id: resource-id,
        start-time: start-time,
        end-time: end-time,
        total-cost: total-cost,
        status: "confirmed",
        created-at: current-block
      }
    )
    ;; Mark time slots as booked
    (mark-time-slots-booked resource-id start-time end-time new-booking-id)
    ;; Update user credits and statistics
    (map-set user-profiles { user: tx-sender }
      (merge user-profile {
        credit-balance: (- (get credit-balance user-profile) total-cost),
        total-bookings: (+ (get total-bookings user-profile) u1)
      })
    )
    ;; Update booking counter
    (var-set booking-id-counter new-booking-id)
    (var-set total-bookings (+ (var-get total-bookings) u1))
    (ok new-booking-id)
  )
)

;; Add credits to user balance (community contribution mechanism)
(define-public (add-user-credits (user principal) (amount uint))
  (let (
    (current-profile (unwrap! (map-get? user-profiles { user: user }) (err err-not-found)))
    (contribution (default-to 
      { total-contributed: u0, resources-shared: u0, community-score: u0, last-contribution: u0 }
      (map-get? contributions { user: tx-sender })
    ))
    (current-block stacks-block-height)
  )
    ;; Only active community members can contribute credits
    (asserts! (> (get community-score contribution) u20) (err err-unauthorized))
    ;; Update user credits
    (map-set user-profiles { user: user }
      (merge current-profile {
        credit-balance: (+ (get credit-balance current-profile) amount)
      })
    )
    ;; Track contribution
    (map-set contributions { user: tx-sender }
      (merge contribution {
        total-contributed: (+ (get total-contributed contribution) amount),
        community-score: (+ (get community-score contribution) (/ amount u10)),
        last-contribution: current-block
      })
    )
    (ok true)
  )
)

;; Cancel a booking
(define-public (cancel-booking (booking-id uint))
  (let (
    (booking (unwrap! (map-get? bookings { booking-id: booking-id }) (err err-not-found)))
    (user-profile (unwrap! (map-get? user-profiles { user: tx-sender }) (err err-unauthorized)))
    (current-block stacks-block-height)
  )
    ;; Only booking owner can cancel
    (asserts! (is-eq (get user booking) tx-sender) (err err-unauthorized))
    ;; Only cancel future bookings
    (asserts! (> (get start-time booking) current-block) (err err-invalid-time))
    ;; Update booking status
    (map-set bookings { booking-id: booking-id }
      (merge booking { status: "cancelled" })
    )
    ;; Refund credits
    (map-set user-profiles { user: tx-sender }
      (merge user-profile {
        credit-balance: (+ (get credit-balance user-profile) (get total-cost booking))
      })
    )
    ;; Free up time slots
    (free-time-slots (get resource-id booking) (get start-time booking) (get end-time booking))
    (ok true)
  )
)

;; Update resource availability
(define-public (set-resource-availability (resource-id uint) (available bool))
  (let (
    (resource (unwrap! (map-get? resources { resource-id: resource-id }) (err err-not-found)))
  )
    ;; Only resource owner can update availability
    (asserts! (is-eq (get owner resource) tx-sender) (err err-unauthorized))
    (map-set resources { resource-id: resource-id }
      (merge resource { availability: available })
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get resource details
(define-read-only (get-resource (resource-id uint))
  (map-get? resources { resource-id: resource-id })
)

;; Get user profile
(define-read-only (get-user-profile (user principal))
  (map-get? user-profiles { user: user })
)

;; Get booking details
(define-read-only (get-booking (booking-id uint))
  (map-get? bookings { booking-id: booking-id })
)

;; Get user contributions
(define-read-only (get-user-contributions (user principal))
  (map-get? contributions { user: user })
)

;; Get total system statistics
(define-read-only (get-system-stats)
  {
    total-resources: (var-get total-resources),
    total-bookings: (var-get total-bookings),
    emergency-mode: (var-get emergency-mode),
    maintenance-window: (var-get maintenance-window)
  }
)

;; Check if a time slot is available
(define-read-only (check-availability (resource-id uint) (time-slot uint))
  (match (map-get? resource-schedule { resource-id: resource-id, time-slot: time-slot })
    schedule (not (get booked schedule))
    true
  )
)

;; Private Functions

;; Simplified time slot availability check (checks single slot)
(define-private (is-time-slot-available (resource-id uint) (start-time uint) (end-time uint))
  ;; For simplicity, just check if start time slot is available
  (check-availability resource-id start-time)
)

;; Mark single time slot as booked (simplified version)
(define-private (mark-time-slots-booked (resource-id uint) (start-time uint) (end-time uint) (booking-id uint))
  (map-set resource-schedule 
    { resource-id: resource-id, time-slot: start-time }
    { booked: true, booking-id: booking-id }
  )
)

;; Free up single time slot (simplified version)
(define-private (free-time-slots (resource-id uint) (start-time uint) (end-time uint))
  (map-delete resource-schedule { resource-id: resource-id, time-slot: start-time })
)
