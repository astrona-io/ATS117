# The Static Seal

The static seal needs no second server and no cloud account. The server reads a 32-byte key from its own configuration and uses it to protect the root key. That makes it the simplest auto-unseal, and also the one whose safety depends entirely on where the key comes from. This part reads the unsealer's static seal and explains the fields, key rotation and when the seal is a good choice.

## A static seal in use

The unsealer in your playground unseals itself with a static seal. Look at its configuration. The ConfigMap name ends in `-config`; list the ConfigMaps if the first command does not find it:

<!-- astrona:playground:renew -->

```sh
kubectl -n unsealer get configmap
kubectl -n unsealer get configmap unsealer-config -o jsonpath='{.data.extraconfig-from-values\.hcl}'
```

The `seal` block looks like this:

```hcl
seal "static" {
  current_key_id = "lab-static-1"
  current_key    = "env://STATIC_UNSEAL_KEY"
}
```

The block has two fields. `current_key_id` is a name for the key. OpenBao stores this name next to what the key encrypts, so it knows later which key to use. `current_key` is the key itself, or a pointer to it. The value `env://STATIC_UNSEAL_KEY` tells OpenBao to read the key from the environment variable of that name, and `file:///path` reads it from a file. A plain value in the configuration file also works and is the least safe choice, because the key then sits in the file and in the ConfigMap.

The chart fills the variable from the Secret `unsealer-static-key`. The key is 32 bytes; the lab creates it as 64 hexadecimal characters with `openssl rand -hex 32`. Check that the unsealer reports the seal:

```sh
kubectl -n unsealer exec -i unsealer-0 -- env BAO_ADDR=http://127.0.0.1:8200 bao status
```

`Seal Type` is `static`, and the unsealer is unsealed without any person entering a share.

## Rotating the static key

To change the key, the block keeps both keys during the change. The new key becomes `current_key`, and the old one moves to `previous_key`, with its own ID:

```hcl
seal "static" {
  current_key_id  = "lab-static-2"
  current_key     = "env://STATIC_UNSEAL_KEY_NEW"
  previous_key_id = "lab-static-1"
  previous_key    = "env://STATIC_UNSEAL_KEY"
}
```

The server uses `current_key` for new encryption and `previous_key` to read what the old key protected. Roll the change out like any configuration change: update the values, then restart the pods one at a time, standbys first. Remove the `previous_key` lines only after every node runs with the new key and you have a fresh snapshot. A node that starts without the key that wrapped its root key stays sealed.

## When the static seal fits

The security of the static seal is the security of the key's place. If the key lives in a Kubernetes Secret, anyone who can read that Secret and the data volume can open the data. The seal fits in three cases: a lab such as this one, a setup where another system injects the key and protects it (a secrets manager, a hardware-backed store), and a small deployment where the risk of a cloud dependency is larger than the risk of the key. For anything else, a Transit or KMS seal keeps the key outside the cluster.

| Seal | Key lives | Depends on | Typical use |
| --- | --- | --- | --- |
| Shamir | In people's hands | People at every restart | Small, rarely restarted clusters |
| Static | In the environment or a file | Whatever injects the key | Labs, injected keys |
| Transit | In another OpenBao | That server and a token | Platforms with a central OpenBao |
| KMS plugin | In a cloud service | The cloud account | Cloud deployments |

You now know the fields of the static seal, how to rotate its key without locking the server out, and where its safety comes from. The remaining seal family is the cloud seals, which run as plugins.

## Common pitfalls

> [!WARNING]
> - **Putting the key in the configuration file.** The key then sits next to the data it protects.
> - **Dropping `previous_key` too early.** A node that still needs the old key stays sealed.
> - **Losing the key.** There is no recovery without it; keep a copy in a place with separate access.
> - **Reusing one key for several clusters.** One leak then opens all of them.
