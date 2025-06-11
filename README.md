# 🤝 Gig Worker Payment Automation

A secure, transparent smart contract system for managing gig worker payments using Stacks blockchain.

## 🎯 Features

- ✅ Escrow-based payment system
- 💰 Milestone-based payments
- 🔒 Secure fund management
- 📝 Proof of work submission
- ✨ Automated payment release

## 🚀 How It Works

1. **Creating a Gig**
   - Employer creates a gig by specifying worker and total payment
   - Funds are locked in the smart contract
   - Milestones are defined upfront

2. **Submitting Work**
   - Worker submits proof of completion for each milestone
   - Proof is stored on-chain for transparency

3. **Payment Release**
   - Employer reviews and approves milestones
   - Payment is automatically released upon approval
   - Final completion updates gig status

## 📋 Contract Functions

### For Employers
- `create-gig`: Create new gig with defined milestones
- `approve-milestone`: Review and approve completed work

### For Workers
- `submit-milestone`: Submit proof of work completion

### Read-Only Functions
- `get-gig`: View gig details
- `get-milestone`: View milestone details

## 🛠️ Usage Example

```clarity
;; Create a new gig
(contract-call? .gig-worker-payment-automation create-gig 
    'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM 
    u1000000 
    u4)

;; Submit milestone proof
(contract-call? .gig-worker-payment-automation submit-milestone 
    u1 
    u1 
    "work_proof_hash")

;; Approve milestone
(contract-call? .gig-worker-payment-automation approve-milestone 
    u1 
    u1)
```

## 🔐 Security

- Funds are locked in contract until milestone approval
- Only authorized parties can perform relevant actions
- Milestone-based release prevents payment disputes
```
