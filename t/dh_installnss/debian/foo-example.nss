hosts before=dns mdns4
hosts before=mdns4 mdns4_minimal [NOTFOUND=return]
hosts remove-only mdns # In case the user manually added it
