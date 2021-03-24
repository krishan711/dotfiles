# Initialise
# NOTE(krishan711): only run this once!

OPENVPN_DATA='/etc/openvpn-data'

docker run -v $OPENVPN_DATA:/etc/openvpn --rm kylemanna/openvpn ovpn_genconfig -u udp://vpn.kiba.dev
docker run -v $OPENVPN_DATA:/etc/openvpn --rm -it kylemanna/openvpn ovpn_initpki

# Run

NAME='openvpn'
OPENVPN_DATA='/etc/openvpn-data'

docker stop $NAME || true
docker rm $NAME || true
docker run -v $OPENVPN_DATA:/etc/openvpn -d -p 1194:1194/udp --cap-add=NET_ADMIN --name $NAME kylemanna/openvpn

# Generate

CLIENTNAME=$1
OPENVPN_DATA='/etc/openvpn-data'

docker run -v $OPENVPN_DATA:/etc/openvpn --rm -it kylemanna/openvpn easyrsa build-client-full $CLIENTNAME nopass
docker run -v $OPENVPN_DATA:/etc/openvpn --rm -it kylemanna/openvpn ovpn_getclient $CLIENTNAME > $CLIENTNAME.ovpn
sed -i '/redirect-gateway def1/# redirect-gateway def1' $CLIENTNAME.ovpn
echo "allow-pull-fqdn" >> $CLIENTNAME.ovpn
echo "route-nopull" >> $CLIENTNAME.ovpn
# NOTE(krishan711): this is specific to kiba's VPC (172.31.0.0/16)
echo "route 172.31.255.255 255.255.0.0" >> $CLIENTNAME.ovpn

rsync certbox:~/$CLIENTNAME.ovpn ~/Downloads

# List

OPENVPN_DATA='/etc/openvpn-data'
docker run -v $OPENVPN_DATA:/etc/openvpn --rm -it kylemanna/openvpn ovpn_listclients

# Revoke

CLIENTNAME=$1
OPENVPN_DATA='/etc/openvpn-data'

docker run -v $OPENVPN_DATA:/etc/openvpn --rm -it kylemanna/openvpn easyrsa revoke $CLIENTNAME
docker run -v $OPENVPN_DATA:/etc/openvpn --rm -it kylemanna/openvpn easyrsa gen-crl
sudo cp $OPENVPN_DATA/pki/crl.pem $OPENVPN_DATA/crl.pem
