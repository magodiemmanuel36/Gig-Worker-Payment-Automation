(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-GIG (err u101))
(define-constant ERR-INSUFFICIENT-FUNDS (err u102))
(define-constant ERR-ALREADY-COMPLETED (err u103))
(define-constant ERR-NOT-FOUND (err u104))
(define-constant ERR-DISPUTE-EXISTS (err u105))
(define-constant ERR-NO-DISPUTE (err u106))
(define-constant ERR-DISPUTE-TIMEOUT (err u107))
(define-constant ERR-ALREADY-RATED (err u108))
(define-constant ERR-INVALID-RATING (err u109))

(define-constant DISPUTE-TIMEOUT-BLOCKS u1008)

(define-data-var contract-owner principal tx-sender)
(define-data-var gig-counter uint u0)

(define-map gigs
    { gig-id: uint }
    {
        employer: principal,
        worker: principal,
        amount: uint,
        status: (string-ascii 20),
        milestone-count: uint,
        completed-milestones: uint,
        employer-rated: bool,
        worker-rated: bool
    }
)

(define-map milestones
    { gig-id: uint, milestone-id: uint }
    {
        amount: uint,
        completed: bool,
        proof: (string-ascii 256)
    }
)

(define-map disputes
    { gig-id: uint, milestone-id: uint }
    {
        initiated-by: principal,
        reason: (string-ascii 256),
        created-at: uint,
        status: (string-ascii 20)
    }
)

(define-map user-reputation
    { user: principal }
    {
        total-rating: uint,
        rating-count: uint,
        completed-gigs: uint,
        total-earned: uint
    }
)

(define-map gig-ratings
    { gig-id: uint, rater: principal }
    {
        rating: uint,
        comment: (string-ascii 256)
    }
)

(define-public (create-gig (worker principal) (total-amount uint) (milestone-count uint))
    (let
        (
            (gig-id (+ (var-get gig-counter) u1))
        )
        (try! (stx-transfer? total-amount tx-sender (as-contract tx-sender)))
        (map-set gigs
            { gig-id: gig-id }
            {
                employer: tx-sender,
                worker: worker,
                amount: total-amount,
                status: "active",
                milestone-count: milestone-count,
                completed-milestones: u0,
                employer-rated: false,
                worker-rated: false
            }
        )
        (var-set gig-counter gig-id)
        (ok gig-id)
    )
)

(define-public (submit-milestone (gig-id uint) (milestone-id uint) (proof (string-ascii 256)))
    (let
        (
            (gig (unwrap! (map-get? gigs { gig-id: gig-id }) ERR-NOT-FOUND))
            (milestone (default-to 
                { amount: u0, completed: false, proof: "" }
                (map-get? milestones { gig-id: gig-id, milestone-id: milestone-id })
            ))
        )
        (asserts! (is-eq (get worker gig) tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status gig) "active") ERR-ALREADY-COMPLETED)
        (map-set milestones
            { gig-id: gig-id, milestone-id: milestone-id }
            {
                amount: (/ (get amount gig) (get milestone-count gig)),
                completed: false,
                proof: proof
            }
        )
        (ok true)
    )
)

(define-public (approve-milestone (gig-id uint) (milestone-id uint))
    (let
        (
            (gig (unwrap! (map-get? gigs { gig-id: gig-id }) ERR-NOT-FOUND))
            (milestone (unwrap! (map-get? milestones { gig-id: gig-id, milestone-id: milestone-id }) ERR-NOT-FOUND))
            (updated-gig (merge gig { completed-milestones: (+ (get completed-milestones gig) u1) }))
        )
        (asserts! (is-eq (get employer gig) tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status gig) "active") ERR-ALREADY-COMPLETED)
        
        (try! (as-contract (stx-transfer? (get amount milestone) tx-sender (get worker gig))))
        
        (map-set milestones
            { gig-id: gig-id, milestone-id: milestone-id }
            (merge milestone { completed: true })
        )
        
        (map-set gigs
            { gig-id: gig-id }
            updated-gig
        )
        
        (begin
            (if (is-eq (get completed-milestones updated-gig) (get milestone-count gig))
                (begin
                    (map-set gigs
                        { gig-id: gig-id }
                        (merge updated-gig { status: "completed" })
                    )
                    true
                )
                true
            )
        )
        (ok true)
    )
)

(define-public (initiate-dispute (gig-id uint) (milestone-id uint) (reason (string-ascii 256)))
    (let
        (
            (gig (unwrap! (map-get? gigs { gig-id: gig-id }) ERR-NOT-FOUND))
            (milestone (unwrap! (map-get? milestones { gig-id: gig-id, milestone-id: milestone-id }) ERR-NOT-FOUND))
            (existing-dispute (map-get? disputes { gig-id: gig-id, milestone-id: milestone-id }))
        )
        (asserts! (is-eq (get worker gig) tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (is-none existing-dispute) ERR-DISPUTE-EXISTS)
        (asserts! (not (get completed milestone)) ERR-ALREADY-COMPLETED)
        
        (map-set disputes
            { gig-id: gig-id, milestone-id: milestone-id }
            {
                initiated-by: tx-sender,
                reason: reason,
                created-at: stacks-block-height,
                status: "pending"
            }
        )
        (ok true)
    )
)

(define-public (resolve-dispute (gig-id uint) (milestone-id uint) (approve-worker bool))
    (let
        (
            (gig (unwrap! (map-get? gigs { gig-id: gig-id }) ERR-NOT-FOUND))
            (milestone (unwrap! (map-get? milestones { gig-id: gig-id, milestone-id: milestone-id }) ERR-NOT-FOUND))
            (dispute (unwrap! (map-get? disputes { gig-id: gig-id, milestone-id: milestone-id }) ERR-NO-DISPUTE))
        )
        (asserts! (is-eq (var-get contract-owner) tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status dispute) "pending") ERR-ALREADY-COMPLETED)
        
        (if approve-worker
            (begin
                (try! (as-contract (stx-transfer? (get amount milestone) tx-sender (get worker gig))))
                (map-set milestones
                    { gig-id: gig-id, milestone-id: milestone-id }
                    (merge milestone { completed: true })
                )
                (map-set gigs
                    { gig-id: gig-id }
                    (merge gig { completed-milestones: (+ (get completed-milestones gig) u1) })
                )
            )
            true
        )
        
        (map-set disputes
            { gig-id: gig-id, milestone-id: milestone-id }
            (merge dispute { status: "resolved" })
        )
        (ok approve-worker)
    )
)

(define-public (auto-resolve-dispute (gig-id uint) (milestone-id uint))
    (let
        (
            (gig (unwrap! (map-get? gigs { gig-id: gig-id }) ERR-NOT-FOUND))
            (milestone (unwrap! (map-get? milestones { gig-id: gig-id, milestone-id: milestone-id }) ERR-NOT-FOUND))
            (dispute (unwrap! (map-get? disputes { gig-id: gig-id, milestone-id: milestone-id }) ERR-NO-DISPUTE))
        )
        (asserts! (>= stacks-block-height (+ (get created-at dispute) DISPUTE-TIMEOUT-BLOCKS)) ERR-DISPUTE-TIMEOUT)
        (asserts! (is-eq (get status dispute) "pending") ERR-ALREADY-COMPLETED)
        
        (try! (as-contract (stx-transfer? (get amount milestone) tx-sender (get worker gig))))
        
        (map-set milestones
            { gig-id: gig-id, milestone-id: milestone-id }
            (merge milestone { completed: true })
        )
        
        (map-set gigs
            { gig-id: gig-id }
            (merge gig { completed-milestones: (+ (get completed-milestones gig) u1) })
        )
        
        (map-set disputes
            { gig-id: gig-id, milestone-id: milestone-id }
            (merge dispute { status: "auto-resolved" })
        )
        (ok true)
    )
)

(define-public (rate-user (gig-id uint) (rating uint) (comment (string-ascii 256)))
    (let
        (
            (gig (unwrap! (map-get? gigs { gig-id: gig-id }) ERR-NOT-FOUND))
            (is-employer (is-eq (get employer gig) tx-sender))
            (is-worker (is-eq (get worker gig) tx-sender))
            (target-user (if is-employer (get worker gig) (get employer gig)))
            (already-rated (if is-employer (get employer-rated gig) (get worker-rated gig)))
        )
        (asserts! (or is-employer is-worker) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status gig) "completed") ERR-INVALID-GIG)
        (asserts! (not already-rated) ERR-ALREADY-RATED)
        (asserts! (and (>= rating u1) (<= rating u5)) ERR-INVALID-RATING)
        
        (map-set gig-ratings
            { gig-id: gig-id, rater: tx-sender }
            { rating: rating, comment: comment }
        )
        
        (begin
            (if is-employer
                (map-set gigs
                    { gig-id: gig-id }
                    (merge gig { employer-rated: true })
                )
                (map-set gigs
                    { gig-id: gig-id }
                    (merge gig { worker-rated: true })
                )
            )
        )
        
        (update-user-reputation target-user rating)
        (ok true)
    )
)

(define-private (update-user-reputation (user principal) (rating uint))
    (let
        (
            (current-rep (default-to
                { total-rating: u0, rating-count: u0, completed-gigs: u0, total-earned: u0 }
                (map-get? user-reputation { user: user })
            ))
        )
        (map-set user-reputation
            { user: user }
            (merge current-rep {
                total-rating: (+ (get total-rating current-rep) rating),
                rating-count: (+ (get rating-count current-rep) u1),
                completed-gigs: (+ (get completed-gigs current-rep) u1)
            })
        )
    )
)

(define-read-only (get-gig (gig-id uint))
    (ok (unwrap! (map-get? gigs { gig-id: gig-id }) ERR-NOT-FOUND))
)

(define-read-only (get-milestone (gig-id uint) (milestone-id uint))
    (ok (unwrap! (map-get? milestones { gig-id: gig-id, milestone-id: milestone-id }) ERR-NOT-FOUND))
)

(define-read-only (get-dispute (gig-id uint) (milestone-id uint))
    (ok (unwrap! (map-get? disputes { gig-id: gig-id, milestone-id: milestone-id }) ERR-NOT-FOUND))
)

(define-read-only (get-user-reputation (user principal))
    (ok (default-to
        { total-rating: u0, rating-count: u0, completed-gigs: u0, total-earned: u0 }
        (map-get? user-reputation { user: user })
    ))
)

(define-read-only (get-rating (gig-id uint) (rater principal))
    (ok (unwrap! (map-get? gig-ratings { gig-id: gig-id, rater: rater }) ERR-NOT-FOUND))
)
