Bring up the test environment:

```
docker compose up -d
```

In one terminal, run a tcpdump on interface `wg0` in `vm2`:

```
docker compose exec vm2 tcpdump -nn -i wg0
```

On your host, connect to port `9735`:

```
$ curl localhost:9735
This is vm2
```

Your tcpdump will show that the request was routed through vm1 over the wireguard interface:

```
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on wg0, link-type RAW (Raw IP), snapshot length 262144 bytes
16:55:49.652990 IP 10.200.200.1.56470 > 10.200.200.2.9735: Flags [S], seq 4109380398, win 64240, options [mss 1460,sackOK,TS val 4191808387 ecr 0,nop,wscale 7], length 0
.
.
.
16:55:49.653587 IP 10.200.200.1.56470 > 10.200.200.2.9735: Flags [.], ack 231, win 501, options [nop,nop,TS val 4191808388 ecr 2741279486], length 0
```
