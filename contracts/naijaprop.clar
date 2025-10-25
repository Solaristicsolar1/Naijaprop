;; NaijaProp - Basic Land NFT Contract

(define-constant ERR-NOT-ADMIN u100)
(define-constant ERR-NOT-OWNER u101)
(define-constant ERR-NFT-NOT-FOUND u102)
(define-constant ERR-ALREADY-EXISTS u107)

;; Admin
(define-data-var admin principal tx-sender)
(define-read-only (get-admin) (ok (var-get admin)))
(define-private (is-admin (p principal)) (is-eq p (var-get admin)))

;; NFT
(define-non-fungible-token land-nft uint)

;; Metadata
(define-map land-metadata
  {token-id: uint}
  {coords: (string-ascii 256),
   size: uint,
   owner-name: (string-ascii 64),
   doc-hash: (buff 32),
   registered: bool,
   notes: (string-ascii 256)})

;; Read functions
(define-read-only (get-land (token-id uint))
  (map-get? land-metadata {token-id: token-id}))

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? land-nft token-id)))

;; Mint function
(define-public (mint-land (token-id uint) (coords (string-ascii 256)) (size uint)
                           (owner-name (string-ascii 64)) (doc-hash (buff 32))
                           (to principal) (notes (string-ascii 256)))
  (begin
    (asserts! (is-admin tx-sender) (err ERR-NOT-ADMIN))
    (asserts! (is-none (nft-get-owner? land-nft token-id)) (err ERR-ALREADY-EXISTS))
    (try! (nft-mint? land-nft token-id to))
    (map-set land-metadata {token-id: token-id}
             {coords: coords,
              size: size,
              owner-name: owner-name,
              doc-hash: doc-hash,
              registered: true,
              notes: notes})
    (ok true)))

;; Transfer function
(define-public (transfer-land (token-id uint) (to principal))
  (let ((owner (nft-get-owner? land-nft token-id)))
    (asserts! (is-some owner) (err ERR-NFT-NOT-FOUND))
    (asserts! (is-eq (unwrap-panic owner) tx-sender) (err ERR-NOT-OWNER))
    (try! (nft-transfer? land-nft token-id tx-sender to))
    (ok true)))

;; SIP-009 compliance
(define-read-only (get-last-token-id)
  (ok u0))

(define-read-only (get-token-uri (token-id uint))
  (ok (some "https://naijaprop.com/metadata/")))

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) (err ERR-NOT-OWNER))
    (transfer-land token-id recipient)))

;; Helper functions
(define-read-only (token-exists (token-id uint))
  (ok (is-some (nft-get-owner? land-nft token-id))))

(define-read-only (verify-doc (token-id uint) (doc-hash (buff 32)))
  (match (map-get? land-metadata {token-id: token-id})
    metadata (ok (is-eq (get doc-hash metadata) doc-hash))
    (err ERR-NFT-NOT-FOUND)))
