OPENVPN_DATA=/home/ec2-user/openvpn-data
OPENVPN_CONTAINER_NAME=openvpn

# for kiba (10.17.0.0/16)
OPENVPN_ADDRESS=udp://34.249.191.66
OPENVPN_ROUTE=10.17.0.0
# for tokenpage (172.31.0.0/16)
OPENVPN_ADDRESS=udp://vpn.tokenpage.xyz
OPENVPN_ROUTE=172.31.0.0

# Initialise (only run this once!)

sudo rm -rf $OPENVPN_DATA
docker run --rm -v $OPENVPN_DATA:/etc/openvpn kylemanna/openvpn ovpn_genconfig -d -N -u $OPENVPN_ADDRESS
docker run --rm -v $OPENVPN_DATA:/etc/openvpn -it kylemanna/openvpn ovpn_initpki

# Run

docker stop $OPENVPN_CONTAINER_NAME || true
docker rm $OPENVPN_CONTAINER_NAME || true
docker run -v $OPENVPN_DATA:/etc/openvpn -d -p 1194:1194/udp --cap-add=NET_ADMIN --name $OPENVPN_CONTAINER_NAME kylemanna/openvpn

# List

docker run -v $OPENVPN_DATA:/etc/openvpn --rm -it kylemanna/openvpn ovpn_listclients

# Generate (run these one at a time)

CLIENTNAME=$1
docker run -v $OPENVPN_DATA:/etc/openvpn --rm -it kylemanna/openvpn easyrsa build-client-full $CLIENTNAME nopass
docker run -v $OPENVPN_DATA:/etc/openvpn --rm -it kylemanna/openvpn ovpn_getclient $CLIENTNAME > $CLIENTNAME.ovpn
sed -i s/redirect-gateway\ def1/#redirect-gateway\ def1/ $CLIENTNAME.ovpn
echo "# allow-pull-fqdn" >> $CLIENTNAME.ovpn
echo "route-nopull" >> $CLIENTNAME.ovpn
echo "route $OPENVPN_ROUTE 255.255.0.0" >> $CLIENTNAME.ovpn

# to download, on target computer:
rsync $BOXNAME:~/$CLIENTNAME.ovpn ~/Downloads

# Revoke (run these one at a time)

CLIENTNAME=$1
docker run -v $OPENVPN_DATA:/etc/openvpn --rm -it kylemanna/openvpn easyrsa revoke $CLIENTNAME
docker run -v $OPENVPN_DATA:/etc/openvpn --rm -it kylemanna/openvpn easyrsa gen-crl
sudo cp $OPENVPN_DATA/pki/crl.pem $OPENVPN_DATA/crl.pem
