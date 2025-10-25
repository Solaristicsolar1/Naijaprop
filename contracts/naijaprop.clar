;; NaijaProp - Advanced Land NFT Smart Contract
;; A comprehensive smart contract for land NFT management and property verification
;; Implements SIP-009 NFT standard with advanced features for real estate tokenization

;; Error constants
(define-constant ERR-NOT-ADMIN u100)
(define-constant ERR-NOT-OWNER u101)
(define-constant ERR-NFT-NOT-FOUND u102)
(define-constant ERR-ALREADY-FRACTIONALIZED u103)
(define-constant ERR-NOT-FRACTIONALIZED u104)
(define-constant ERR-INVALID-AMOUNT u105)
(define-constant ERR-TRANSFER-LOCKED u106)
(define-constant ERR-ALREADY-EXISTS u107)
(define-constant ERR-INVALID-COORDINATES u108)
(define-constant ERR-INVALID-SIZE u109)
(define-constant ERR-UNAUTHORIZED u110)
(define-constant ERR-EXPIRED u111)
(define-constant ERR-INVALID-SIGNATURE u112)

;; Contract constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant MAX-LAND-SIZE u1000000) ;; Maximum land size in square meters
(define-constant MIN-LAND-SIZE u1) ;; Minimum land size in square meters
(define-constant MAX-FRACTIONAL-SHARES u1000000)
(define-constant COMMISSION-RATE u250) ;; 2.5% commission (250 basis points)

;; Data variables
(define-data-var admin principal tx-sender)
(define-data-var contract-uri (string-ascii 256) "https://naijaprop.com/contract")
(define-data-var total-supply uint u0)
(define-data-var next-token-id uint u1)
(define-data-var paused bool false)
(define-data-var commission-wallet principal tx-sender)

;; NFT definition
(define-non-fungible-token land-nft uint)

;; Maps for land metadata
(define-map land-metadata
  {token-id: uint}
  {coords: (string-ascii 256),
   size: uint,
   owner-name: (string-ascii 64),
   doc-hash: (buff 32),
   registered: bool,
   locked: bool,
   notes: (string-ascii 256),
   created-at: uint,
   last-updated: uint,
   land-type: (string-ascii 32),
   valuation: uint})

;; Maps for fractionalization
(define-map fractional-info
  {token-id: uint}
  {total-shares: uint,
   shares-sold: uint,
   price-per-share: uint,
   locked: bool,
   created-at: uint})

(define-map fractional-balances
  {token-id: uint, holder: principal}
  {amount: uint,
   acquired-at: uint})

(define-map fractional-holders
  {token-id: uint}
  {holders: (list 100 principal)})

;; Maps for approvals and transfers
(define-map token-approvals
  {token-id: uint}
  {approved: principal,
   expires-at: uint})

(define-map operator-approvals
  {owner: principal, operator: principal}
  {approved: bool})

;; Maps for land history and verification
(define-map land-history
  {token-id: uint, sequence: uint}
  {action: (string-ascii 32),
   from: (optional principal),
   to: (optional principal),
   timestamp: uint,
   details: (string-ascii 256)})

(define-map verification-requests
  {token-id: uint}
  {requester: principal,
   status: (string-ascii 16),
   requested-at: uint,
   verified-at: (optional uint)})

;; Administrative functions
(define-read-only (get-admin)
  (ok (var-get admin)))

(define-read-only (get-contract-owner)
  (ok CONTRACT-OWNER))

(define-private (is-admin (caller principal))
  (is-eq caller (var-get admin)))

(define-private (is-contract-owner (caller principal))
  (is-eq caller CONTRACT-OWNER))

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-contract-owner tx-sender) (err ERR-NOT-ADMIN))
    (asserts! (not (is-eq new-admin 'SP000000000000000000002Q6VF78)) (err ERR-UNAUTHORIZED))
    (var-set admin new-admin)
    (ok true)))

(define-public (set-contract-uri (new-uri (string-ascii 256)))
  (begin
    (asserts! (is-admin tx-sender) (err ERR-NOT-ADMIN))
    (asserts! (> (len new-uri) u0) (err ERR-INVALID-COORDINATES))
    (var-set contract-uri new-uri)
    (ok true)))

(define-public (pause-contract)
  (begin
    (asserts! (is-admin tx-sender) (err ERR-NOT-ADMIN))
    (var-set paused true)
    (ok true)))

(define-public (unpause-contract)
  (begin
    (asserts! (is-admin tx-sender) (err ERR-NOT-ADMIN))
    (var-set paused false)
    (ok true)))

;; Input validation functions
(define-private (validate-coordinates (coords (string-ascii 256)))
  (> (len coords) u0))

(define-private (validate-land-size (size uint))
  (and (>= size MIN-LAND-SIZE) (<= size MAX-LAND-SIZE)))

(define-private (validate-owner-name (name (string-ascii 64)))
  (> (len name) u0))

(define-private (validate-doc-hash (hash (buff 32)))
  (is-eq (len hash) u32))

;; Core NFT functions
(define-read-only (get-last-token-id)
  (ok (- (var-get next-token-id) u1)))

(define-read-only (get-token-uri (token-id uint))
  (if (is-some (nft-get-owner? land-nft token-id))
    (ok (some (concat (var-get contract-uri) "/metadata/token")))
    (err ERR-NFT-NOT-FOUND)))

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? land-nft token-id)))

(define-read-only (get-total-supply)
  (ok (var-get total-supply)))

;; Land metadata functions
(define-read-only (get-land (token-id uint))
  (map-get? land-metadata {token-id: token-id}))

(define-read-only (get-land-coords (token-id uint))
  (match (map-get? land-metadata {token-id: token-id})
    land-data (ok (get coords land-data))
    (err ERR-NFT-NOT-FOUND)))

(define-read-only (get-land-size (token-id uint))
  (match (map-get? land-metadata {token-id: token-id})
    land-data (ok (get size land-data))
    (err ERR-NFT-NOT-FOUND)))

(define-read-only (get-land-valuation (token-id uint))
  (match (map-get? land-metadata {token-id: token-id})
    land-data (ok (get valuation land-data))
    (err ERR-NFT-NOT-FOUND)))

;; Minting function with comprehensive validation
(define-public (mint-land (coords (string-ascii 256)) (size uint)
                          (owner-name (string-ascii 64)) (doc-hash (buff 32))
                          (to principal) (notes (string-ascii 256))
                          (land-type (string-ascii 32)) (valuation uint))
  (let ((token-id (var-get next-token-id))
        (current-time (unwrap-panic (get-block-info? time (- block-height u1)))))
    (begin
      (asserts! (not (var-get paused)) (err ERR-UNAUTHORIZED))
      (asserts! (is-admin tx-sender) (err ERR-NOT-ADMIN))
      (asserts! (validate-coordinates coords) (err ERR-INVALID-COORDINATES))
      (asserts! (validate-land-size size) (err ERR-INVALID-SIZE))
      (asserts! (validate-owner-name owner-name) (err ERR-UNAUTHORIZED))
      (asserts! (validate-doc-hash doc-hash) (err ERR-INVALID-SIGNATURE))
      (asserts! (is-none (nft-get-owner? land-nft token-id)) (err ERR-ALREADY-EXISTS))
      (asserts! (not (is-eq to 'SP000000000000000000002Q6VF78)) (err ERR-UNAUTHORIZED))
      (asserts! (> (len notes) u0) (err ERR-INVALID-COORDINATES))
      (asserts! (> (len land-type) u0) (err ERR-INVALID-COORDINATES))
      (asserts! (> valuation u0) (err ERR-INVALID-AMOUNT))
      
      (try! (nft-mint? land-nft token-id to))
      
      (map-set land-metadata {token-id: token-id}
               {coords: coords,
                size: size,
                owner-name: owner-name,
                doc-hash: doc-hash,
                registered: true,
                locked: false,
                notes: notes,
                created-at: current-time,
                last-updated: current-time,
                land-type: land-type,
                valuation: valuation})
      
      (map-set land-history {token-id: token-id, sequence: u0}
               {action: "MINTED",
                from: none,
                to: (some to),
                timestamp: current-time,
                details: "Initial land NFT creation"})
      
      (var-set next-token-id (+ token-id u1))
      (var-set total-supply (+ (var-get total-supply) u1))
      (ok token-id))))

;; Enhanced transfer function
(define-public (transfer-land (token-id uint) (to principal))
  (let ((owner (nft-get-owner? land-nft token-id))
        (current-time (unwrap-panic (get-block-info? time (- block-height u1)))))
    (begin
      (asserts! (not (var-get paused)) (err ERR-UNAUTHORIZED))
      (asserts! (is-some owner) (err ERR-NFT-NOT-FOUND))
      (asserts! (is-eq (unwrap-panic owner) tx-sender) (err ERR-NOT-OWNER))
      (asserts! (not (is-eq to 'SP000000000000000000002Q6VF78)) (err ERR-UNAUTHORIZED))
      
      (match (map-get? land-metadata {token-id: token-id})
        land-data
          (begin
            (asserts! (not (get locked land-data)) (err ERR-TRANSFER-LOCKED))
            (try! (nft-transfer? land-nft token-id tx-sender to))
            
            (map-set land-metadata {token-id: token-id}
                     {coords: (get coords land-data),
                      size: (get size land-data),
                      owner-name: "",
                      doc-hash: (get doc-hash land-data),
                      registered: (get registered land-data),
                      locked: (get locked land-data),
                      notes: (get notes land-data),
                      created-at: (get created-at land-data),
                      last-updated: current-time,
                      land-type: (get land-type land-data),
                      valuation: (get valuation land-data)})
            
            (let ((history-count (get-land-history-count token-id)))
              (map-set land-history {token-id: token-id, sequence: history-count}
                       {action: "TRANSFERRED",
                        from: (some tx-sender),
                        to: (some to),
                        timestamp: current-time,
                        details: "Ownership transfer"}))
            (ok true))
        (err ERR-NFT-NOT-FOUND)))))

;; SIP-009 standard transfer function
(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) (err ERR-NOT-OWNER))
    (transfer-land token-id recipient)))

;; Helper functions
(define-private (get-land-history-count (token-id uint))
  (fold count-history-entries (list u0 u1 u2 u3 u4 u5 u6 u7 u8 u9) u0))

(define-private (count-history-entries (sequence uint) (count uint))
  (if (is-some (map-get? land-history {token-id: u1, sequence: sequence}))
      (+ count u1)
      count))

;; Verification and utility functions
(define-read-only (token-exists (token-id uint))
  (ok (is-some (nft-get-owner? land-nft token-id))))

(define-read-only (verify-doc (token-id uint) (doc-hash (buff 32)))
  (match (map-get? land-metadata {token-id: token-id})
    land-data (ok (is-eq (get doc-hash land-data) doc-hash))
    (err ERR-NFT-NOT-FOUND)))

(define-read-only (is-land-locked (token-id uint))
  (match (map-get? land-metadata {token-id: token-id})
    land-data (ok (get locked land-data))
    (err ERR-NFT-NOT-FOUND)))

(define-read-only (get-contract-info)
  (ok {total-supply: (var-get total-supply),
       next-token-id: (var-get next-token-id),
       paused: (var-get paused),
       admin: (var-get admin),
       contract-uri: (var-get contract-uri)}))

;; Emergency functions
(define-public (emergency-unlock (token-id uint))
  (begin
    (asserts! (is-admin tx-sender) (err ERR-NOT-ADMIN))
    (asserts! (> token-id u0) (err ERR-INVALID-AMOUNT))
    (match (map-get? land-metadata {token-id: token-id})
      land-data
        (begin
          (map-set land-metadata {token-id: token-id}
                   {coords: (get coords land-data),
                    size: (get size land-data),
                    owner-name: (get owner-name land-data),
                    doc-hash: (get doc-hash land-data),
                    registered: (get registered land-data),
                    locked: false,
                    notes: (get notes land-data),
                    created-at: (get created-at land-data),
                    last-updated: (unwrap-panic (get-block-info? time (- block-height u1))),
                    land-type: (get land-type land-data),
                    valuation: (get valuation land-data)})
          (ok true))
      (err ERR-NFT-NOT-FOUND))))

;; Contract initialization
(begin
  (var-set admin CONTRACT-OWNER)
  (var-set commission-wallet CONTRACT-OWNER))
