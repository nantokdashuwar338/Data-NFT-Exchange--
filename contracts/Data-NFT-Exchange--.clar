(define-non-fungible-token data-nft uint)

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-NOT-AUTHORIZED (err u101))
(define-constant ERR-TOKEN-NOT-FOUND (err u102))
(define-constant ERR-ALREADY-LICENSED (err u103))
(define-constant ERR-INVALID-PRICE (err u104))
(define-constant ERR-INVALID-ROYALTY (err u105))
(define-constant ERR-INSUFFICIENT-FUNDS (err u106))
(define-constant ERR-LICENSE-EXPIRED (err u107))
(define-constant ERR-SUBSCRIPTION-EXISTS (err u108))
(define-constant ERR-INVALID-DURATION (err u109))

(define-data-var token-id-nonce uint u0)
(define-data-var platform-fee-rate uint u250)

(define-map token-metadata
  uint
  {
    name: (string-ascii 50),
    description: (string-ascii 200),
    dataset-hash: (string-ascii 64),
    creator: principal,
    price: uint,
    royalty-rate: uint,
    license-duration: uint,
    created-at: uint
  }
)

(define-map dataset-licenses
  {token-id: uint, licensee: principal}
  {
    licensed-at: uint,
    expires-at: uint,
    price-paid: uint
  }
)

(define-map user-royalties principal uint)

(define-map dataset-subscriptions
  {subscriber: principal, token-id: uint}
  {
    started-at: uint,
    expires-at: uint,
    monthly-fee: uint,
    auto-renew: bool
  }
)

(define-map subscription-earnings principal uint)

(define-public (mint-dataset (name (string-ascii 50))
                           (description (string-ascii 200))
                           (dataset-hash (string-ascii 64))
                           (price uint)
                           (royalty-rate uint)
                           (license-duration uint))
  (let
    (
      (next-id (+ (var-get token-id-nonce) u1))
      (current-block stacks-block-height)
    )
    (asserts! (> price u0) ERR-INVALID-PRICE)
    (asserts! (<= royalty-rate u1000) ERR-INVALID-ROYALTY)
    (try! (nft-mint? data-nft next-id tx-sender))
    (map-set token-metadata next-id
      {
        name: name,
        description: description,
        dataset-hash: dataset-hash,
        creator: tx-sender,
        price: price,
        royalty-rate: royalty-rate,
        license-duration: license-duration,
        created-at: current-block
      }
    )
    (var-set token-id-nonce next-id)
    (ok next-id)
  )
)

(define-public (license-dataset (token-id uint))
  (let
    (
      (token-data (unwrap! (map-get? token-metadata token-id) ERR-TOKEN-NOT-FOUND))
      (current-block stacks-block-height)
      (expires-at (+ current-block (get license-duration token-data)))
      (license-key {token-id: token-id, licensee: tx-sender})
      (existing-license (map-get? dataset-licenses license-key))
      (price (get price token-data))
      (creator (get creator token-data))
      (royalty-rate (get royalty-rate token-data))
      (platform-fee (/ (* price (var-get platform-fee-rate)) u10000))
      (royalty-amount (/ (* price royalty-rate) u10000))
      (creator-amount (- price (+ platform-fee royalty-amount)))
    )
    (asserts! (is-none existing-license) ERR-ALREADY-LICENSED)
    (asserts! (>= (stx-get-balance tx-sender) price) ERR-INSUFFICIENT-FUNDS)
    (try! (stx-transfer? platform-fee tx-sender CONTRACT-OWNER))
    (try! (stx-transfer? creator-amount tx-sender creator))
    (try! (stx-transfer? royalty-amount tx-sender creator))
    (map-set dataset-licenses license-key
      {
        licensed-at: current-block,
        expires-at: expires-at,
        price-paid: price
      }
    )
    (map-set user-royalties creator 
      (+ (default-to u0 (map-get? user-royalties creator)) royalty-amount)
    )
    (ok expires-at)
  )
)

(define-public (update-dataset-price (token-id uint) (new-price uint))
  (let
    (
      (token-data (unwrap! (map-get? token-metadata token-id) ERR-TOKEN-NOT-FOUND))
      (token-owner (unwrap! (nft-get-owner? data-nft token-id) ERR-TOKEN-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender token-owner) ERR-NOT-AUTHORIZED)
    (asserts! (> new-price u0) ERR-INVALID-PRICE)
    (map-set token-metadata token-id
      (merge token-data {price: new-price})
    )
    (ok true)
  )
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
    (try! (nft-transfer? data-nft token-id sender recipient))
    (ok true)
  )
)

(define-public (set-platform-fee (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (asserts! (<= new-rate u1000) ERR-INVALID-ROYALTY)
    (var-set platform-fee-rate new-rate)
    (ok true)
  )
)

(define-public (withdraw-royalties)
  (let
    (
      (royalty-balance (default-to u0 (map-get? user-royalties tx-sender)))
    )
    (asserts! (> royalty-balance u0) ERR-INSUFFICIENT-FUNDS)
    (try! (as-contract (stx-transfer? royalty-balance tx-sender tx-sender)))
    (map-delete user-royalties tx-sender)
    (ok royalty-balance)
  )
)

(define-public (subscribe-to-dataset (token-id uint) (monthly-fee uint) (duration-months uint))
  (let
    (
      (subscription-key {subscriber: tx-sender, token-id: token-id})
      (existing-subscription (map-get? dataset-subscriptions subscription-key))
      (current-block stacks-block-height)
      (duration-blocks (* duration-months u4320))
      (expires-at (+ current-block duration-blocks))
      (total-cost (* monthly-fee duration-months))
      (token-data (unwrap! (map-get? token-metadata token-id) ERR-TOKEN-NOT-FOUND))
      (creator (get creator token-data))
      (platform-fee (/ (* total-cost (var-get platform-fee-rate)) u10000))
      (creator-amount (- total-cost platform-fee))
    )
    (asserts! (> monthly-fee u0) ERR-INVALID-PRICE)
    (asserts! (and (>= duration-months u1) (<= duration-months u12)) ERR-INVALID-DURATION)
    (asserts! (is-none existing-subscription) ERR-SUBSCRIPTION-EXISTS)
    (asserts! (>= (stx-get-balance tx-sender) total-cost) ERR-INSUFFICIENT-FUNDS)
    (try! (stx-transfer? platform-fee tx-sender CONTRACT-OWNER))
    (try! (stx-transfer? creator-amount tx-sender creator))
    (map-set dataset-subscriptions subscription-key
      {
        started-at: current-block,
        expires-at: expires-at,
        monthly-fee: monthly-fee,
        auto-renew: false
      }
    )
    (map-set subscription-earnings creator
      (+ (default-to u0 (map-get? subscription-earnings creator)) creator-amount)
    )
    (ok expires-at)
  )
)

(define-public (renew-subscription (token-id uint) (duration-months uint))
  (let
    (
      (subscription-key {subscriber: tx-sender, token-id: token-id})
      (subscription (unwrap! (map-get? dataset-subscriptions subscription-key) ERR-TOKEN-NOT-FOUND))
      (monthly-fee (get monthly-fee subscription))
      (total-cost (* monthly-fee duration-months))
      (duration-blocks (* duration-months u4320))
      (current-block stacks-block-height)
      (new-expires-at (+ current-block duration-blocks))
      (token-data (unwrap! (map-get? token-metadata token-id) ERR-TOKEN-NOT-FOUND))
      (creator (get creator token-data))
      (platform-fee (/ (* total-cost (var-get platform-fee-rate)) u10000))
      (creator-amount (- total-cost platform-fee))
    )
    (asserts! (and (>= duration-months u1) (<= duration-months u12)) ERR-INVALID-DURATION)
    (asserts! (>= (stx-get-balance tx-sender) total-cost) ERR-INSUFFICIENT-FUNDS)
    (try! (stx-transfer? platform-fee tx-sender CONTRACT-OWNER))
    (try! (stx-transfer? creator-amount tx-sender creator))
    (map-set dataset-subscriptions subscription-key
      (merge subscription {expires-at: new-expires-at})
    )
    (map-set subscription-earnings creator
      (+ (default-to u0 (map-get? subscription-earnings creator)) creator-amount)
    )
    (ok new-expires-at)
  )
)

(define-public (cancel-subscription (token-id uint))
  (let
    (
      (subscription-key {subscriber: tx-sender, token-id: token-id})
    )
    (asserts! (is-some (map-get? dataset-subscriptions subscription-key)) ERR-TOKEN-NOT-FOUND)
    (map-delete dataset-subscriptions subscription-key)
    (ok true)
  )
)

(define-public (withdraw-subscription-earnings)
  (let
    (
      (earnings (default-to u0 (map-get? subscription-earnings tx-sender)))
    )
    (asserts! (> earnings u0) ERR-INSUFFICIENT-FUNDS)
    (try! (as-contract (stx-transfer? earnings tx-sender tx-sender)))
    (map-delete subscription-earnings tx-sender)
    (ok earnings)
  )
)

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? data-nft token-id))
)

(define-read-only (get-last-token-id)
  (ok (var-get token-id-nonce))
)

(define-read-only (get-token-uri (token-id uint))
  (ok none)
)

(define-read-only (get-dataset-metadata (token-id uint))
  (map-get? token-metadata token-id)
)

(define-read-only (get-license-info (token-id uint) (licensee principal))
  (map-get? dataset-licenses {token-id: token-id, licensee: licensee})
)

(define-read-only (is-license-valid (token-id uint) (licensee principal))
  (let
    (
      (license-info (map-get? dataset-licenses {token-id: token-id, licensee: licensee}))
      (current-block stacks-block-height)
    )
    (match license-info
      license (< current-block (get expires-at license))
      false
    )
  )
)

(define-read-only (get-user-royalties (user principal))
  (default-to u0 (map-get? user-royalties user))
)

(define-read-only (get-platform-fee-rate)
  (var-get platform-fee-rate)
)

(define-read-only (calculate-licensing-costs (token-id uint))
  (let
    (
      (token-data (map-get? token-metadata token-id))
    )
    (match token-data
      data (let
        (
          (price (get price data))
          (royalty-rate (get royalty-rate data))
          (platform-fee (/ (* price (var-get platform-fee-rate)) u10000))
          (royalty-amount (/ (* price royalty-rate) u10000))
          (creator-amount (- price (+ platform-fee royalty-amount)))
        )
        (some {
          total-price: price,
          platform-fee: platform-fee,
          creator-amount: creator-amount,
          royalty-amount: royalty-amount
        })
      )
      none
    )
  )
)

(define-read-only (get-datasets-by-creator (creator principal))
  (ok "Use external indexer")
)

(define-read-only (get-subscription (subscriber principal) (token-id uint))
  (map-get? dataset-subscriptions {subscriber: subscriber, token-id: token-id})
)

(define-read-only (is-subscription-active (subscriber principal) (token-id uint))
  (let
    (
      (subscription (map-get? dataset-subscriptions {subscriber: subscriber, token-id: token-id}))
      (current-block stacks-block-height)
    )
    (match subscription
      sub (< current-block (get expires-at sub))
      false
    )
  )
)

(define-read-only (get-subscription-earnings (creator principal))
  (default-to u0 (map-get? subscription-earnings creator))
)

(define-read-only (verify-dataset-access (token-id uint) (user principal))
  (let
    (
      (is-owner (is-eq (some user) (nft-get-owner? data-nft token-id)))
      (has-valid-license (is-license-valid token-id user))
      (has-active-subscription (is-subscription-active user token-id))
    )
    (or is-owner (or has-valid-license has-active-subscription))
  )
)