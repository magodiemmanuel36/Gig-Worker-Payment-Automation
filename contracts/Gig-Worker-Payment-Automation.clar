(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-GIG (err u101))
(define-constant ERR-INSUFFICIENT-FUNDS (err u102))
(define-constant ERR-ALREADY-COMPLETED (err u103))
(define-constant ERR-NOT-FOUND (err u104))

(define-data-var contract-owner principal tx-sender)

(define-map gigs
    { gig-id: uint }
    {
        employer: principal,
        worker: principal,
        amount: uint,
        status: (string-ascii 20),
        milestone-count: uint,
        completed-milestones: uint
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

(define-data-var gig-counter uint u0)

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
                completed-milestones: u0
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
            (merge gig { completed-milestones: (+ (get completed-milestones gig) u1) })
        )
        
        (if (is-eq (+ (get completed-milestones gig) u1) (get milestone-count gig))
            (map-set gigs
                { gig-id: gig-id }
                (merge gig { status: "completed" })
            )
            true
        )
        (ok true)
    )
)

(define-read-only (get-gig (gig-id uint))
    (ok (unwrap! (map-get? gigs { gig-id: gig-id }) ERR-NOT-FOUND))
)

(define-read-only (get-milestone (gig-id uint) (milestone-id uint))
    (ok (unwrap! (map-get? milestones { gig-id: gig-id, milestone-id: milestone-id }) ERR-NOT-FOUND))
)
