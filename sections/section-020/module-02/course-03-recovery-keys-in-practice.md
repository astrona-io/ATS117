# Recovery Keys In Practice

With auto-unseal, the key shares that `bao operator init` prints are called recovery keys. They cannot unseal the server. They authorize a small set of sensitive operations, and the most common one is creating a new root token when nobody has the old one. This part uses the recovery key to generate a root token and explains when to rekey the recovery keys.

## What recovery keys authorize

Shamir key shares unseal the server. Recovery keys take over a different role: the key service unseals the server, and the recovery keys protect actions that should need several people. The actions are generating a root token, rekeying the recovery keys, and sealing and migrating the seal. The playground uses one recovery share, which is in the Secret `openbao-init` under the key `unseal-key`; a real cluster uses several shares held by different people and a threshold.

## Generating a root token

The root token has all permissions and should not exist in daily use. When you need one, you create it with the recovery keys and revoke it afterwards. The process has three steps. First, start the generation. It returns a nonce and a one-time password (OTP):

<!-- astrona:playground:renew -->

```sh
export BAO_TOKEN=$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.root-token}' | base64 -d)
bao_on() { pod=$1; shift; kubectl -n openbao exec -i "$pod" -- env BAO_ADDR=http://127.0.0.1:8200 BAO_TOKEN="$BAO_TOKEN" bao "$@"; }
bao_on openbao-0 operator generate-root -init
```

Write down the `Nonce` and the `OTP` from the output. The second step sends the recovery key. The command prints an encoded token:

```sh
bao_on openbao-0 operator generate-root -nonce=<NONCE> "$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.unseal-key}' | base64 -d)"
```

Replace `<NONCE>` with the value from the first step. When the threshold of recovery keys is reached, the output shows `Complete` as `true` and the `Encoded Token`. The third step decodes it with the OTP:

```sh
bao_on openbao-0 operator generate-root -decode=<ENCODED_TOKEN> -otp=<OTP>
```

The result is a new root token. Use it once, then revoke it with `bao token revoke`. The encoding exists so that the token never appears in a form that the people who entered the shares can read.

If you start a generation and do not finish it, cancel it with `bao operator generate-root -cancel`. Only one generation can run at a time.

## Rekeying the recovery keys

Rekeying replaces the recovery shares with new ones, for example when a person who held a share leaves. It follows the same pattern with `-target=recovery`:

```sh
bao operator rekey -target=recovery -init -key-shares=3 -key-threshold=2
```

The command returns a nonce. Each key holder then runs `bao operator rekey -target=recovery -nonce=<NONCE>` and enters a share, until the threshold is reached and the new shares are printed. Do not run the rekey in the playground unless you save the new shares: the lab keeps the old share in the Secret `openbao-init`, and graders in other environments rely on it.

Without `-target=recovery`, `rekey` would act on the unseal key, which an auto-unseal cluster does not have. Always set the target.

You now know what the recovery keys are for, how a root token is generated from them, and how they are replaced. The next part covers the other built-in seal that does not need a second server: the static seal.

## Common pitfalls

> [!WARNING]
> - **Treating recovery keys as unseal keys.** They cannot unseal a cluster that uses a key service.
> - **Keeping a root token.** Generate one when needed and revoke it at once.
> - **Losing the nonce or the OTP.** The generation cannot be finished; cancel it and start again.
> - **Forgetting `-target=recovery` on rekey.** The command then talks about the wrong key set.
