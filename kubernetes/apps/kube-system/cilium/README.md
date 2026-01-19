# Cilium

## Fortigate BGP

```sh
config router bgp
    set as 65001
    set router-id 172.16.60.1
    config neighbor
        edit "172.16.60.7"
            set remote-as 65003
            ### check on next-hop-self
            ### check on soft-reconfiguration inbound
        next
        edit "172.16.60.8"
            set remote-as 65003
            ### check on next-hop-self
            ### check on soft-reconfiguration inbound
        next
    end
    config redistribute "connected"
    end
    config redistribute "static"
    end
end
```
