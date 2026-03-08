# Quai Wallet Setup (Pelagus)

Before you can mine Quai, you need a wallet address to receive payouts. Pelagus is the official browser extension wallet for Quai Network — the equivalent of MetaMask but for Quai.

> ⚠️ **Shard matters for mining.** Most pools (including HeroMiners) only pay out to **Cyprus-1** addresses. Make sure your mining account is on the correct shard or payouts will not arrive.

---

## 1. Install the Pelagus Extension

1. Open Chrome, Brave, or another Chromium-based browser
2. Go to the Chrome Web Store and search for **Pelagus**, or visit:
   - [https://pelaguswallet.io](https://pelaguswallet.io) and click **Download**
3. Click **Add to Chrome** and confirm the installation
4. Pin the extension to your toolbar for easy access

> Make sure you're installing the current mainnet version simply called **"Pelagus"** — not the old deprecated "Pelagus (Iron Age)" testnet wallet.

---

## 2. Create a New Wallet

1. Click the Pelagus icon in your toolbar
2. Select **Create a new wallet**
3. Choose and confirm a strong password
4. You'll be shown a **24-word seed phrase** — this is your wallet backup

> 🔐 **Write your seed phrase down on paper and store it somewhere safe offline. Anyone with this phrase has full access to your wallet. Never store it digitally or share it with anyone.**

5. Confirm your seed phrase when prompted
6. Your wallet is now created

---

## 3. Get Your Mining Address (Cyprus-1)

Mining pools pay out to a specific shard. Most pools require **Cyprus-1**.

1. Click your account name at the top of the Pelagus wallet
2. Check which **Shard** is shown
   - If it says **Cyprus-1** — you're good, proceed to step 4
   - If it shows a different shard — continue below to create a Cyprus-1 account

**To create a Cyprus-1 account:**
1. Click **+ Add Quai account**
2. Select Shard **Cyprus-1**
3. Click **Confirm**
4. Click the new account to set it as your active account

---

## 4. Copy Your Wallet Address

1. In the Pelagus wallet, click **Receive**
2. Click your wallet address to copy it
3. This is your `WALLET` value for the quai-miner stack

Your address will look something like:
```
0x001a3f47bf02a00a823b7e51f53e7e49f8bce9a2
```

---

## 5. Set Your Wallet in Portainer

In Portainer, set the following environment variables for the `quai-miner` stack:

```
WALLET=0xYOUR_COPIED_ADDRESS
WORKER=<worker-name>
ALGO=kawpow
POOL=stratum+tcp://us.quai.herominers.com:1185
```

See [`ENV_VARS_REFERENCE.md`](../ENV_VARS_REFERENCE.md) for the full quai-miner variable reference.

---

## Security Reminders

- Never enter your seed phrase into any website or app other than Pelagus itself
- Your wallet address (starting with `0x`) is safe to share publicly — it's how you receive payments
- Your seed phrase and private key are never safe to share — treat them like a password to your bank account
- Consider a hardware wallet (e.g. Ledger) for long-term storage of significant amounts
