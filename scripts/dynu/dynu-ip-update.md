# Set up instructions and notes


```plaintext
timer → service → script
                     ├─ lock (no concurrency)
                     ├─ DNS attempt (logged)
                     ├─ HTTP fallback (logged)
                     ├─ validate
                     ├─ compare with state
                     ├─ update Dynu (bounded time)
                     ├─ atomic state write
                     └─ structured logs
```

