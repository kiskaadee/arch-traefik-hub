#!/bin/bash

# List of domains to check
DOMAINS=(
"arch-services.mywire.org"
"auth.arch-services.mywire.org"
"excalidraw.arch-services.mywire.org"
"gitea.arch-services.mywire.org"
"jellyfin.arch-services.mywire.org"
"learning.arch-services.mywire.org"
"logs.arch-services.mywire.org"
"mermaid.arch-services.mywire.org"
"ollama.arch-services.mywire.org"
"portainer.arch-services.mywire.org"
"traefik.arch-services.mywire.org"
)

printf "%-40s | %-30s | %-30s | %-20s\n" "Domain" "Issuer (CN)" "Subject (CN)" "Expiry"
printf "%-40s-|-%-30s-|-%-30s-|-%-20s\n" "----------------------------------------" "------------------------------" "------------------------------" "--------------------"

for domain in "${DOMAINS[@]}"; do
    # Use timeout to avoid hanging on failed connections
    cert_info=$(timeout 5 bash -c "echo | openssl s_client -showcerts -servername $domain -connect $domain:443 2>/dev/null | openssl x509 -noout -issuer -subject -enddate 2>/dev/null")
    
    if [ -z "$cert_info" ]; then
        printf "%-40s | %-30s | %-30s | %-20s\n" "$domain" "CONNECTION FAILED" "-" "-"
    else
        # Extract CN from issuer and subject
        issuer_cn=$(echo "$cert_info" | grep "issuer" | sed -n 's/.*CN = \([^,]*\).*/\1/p')
        [ -z "$issuer_cn" ] && issuer_cn=$(echo "$cert_info" | grep "issuer" | sed 's/issuer= //')
        
        subject_cn=$(echo "$cert_info" | grep "subject" | sed -n 's/.*CN = \([^,]*\).*/\1/p')
        [ -z "$subject_cn" ] && subject_cn=$(echo "$cert_info" | grep "subject" | sed 's/subject= //')
        
        expiry=$(echo "$cert_info" | grep "notAfter" | sed 's/notAfter=//')
        
        printf "%-40s | %-30s | %-30s | %-20s\n" "$domain" "$issuer_cn" "$subject_cn" "$expiry"
    fi
done
