# Define las variables como lo haría el script
FQDN="a1hemostasiad2.santpau.es"
IP="172.31.104.65"
OLD_FQDN_OF_PTR="ws065.x31-104.santpau.es"
LAST_OCTET=$(echo "$IP" | awk -F. '{print $4}')

# Conéctate a dns01 y simplemente "imprime" el comando sed que se generaría
ssh root@dns01.santpau.es "echo \"sed -i 's/^\s*${LAST_OCTET}\s\+IN\s\+PTR\s\+${OLD_FQDN_OF_PTR}\..*$/${LAST_OCTET}\t\tIN\tPTR\t${FQDN}./' /var/lib/named/master/db.172.31.104\""
