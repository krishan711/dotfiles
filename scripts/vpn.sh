#!/bin/bash
set -euo pipefail

OPENVPN_DATA=/home/ec2-user/openvpn-data
OPENVPN_CONTAINER_NAME=openvpn
OPENVPN_ADDRESS=udp://<fill>
OPENVPN_ROUTE=<fill>
BOXNAME=<fill>

usage() {
  echo "Usage: $0 <command> [clientname]"
  echo ""
  echo "Commands:"
  echo "  init               Initialise VPN data (one-time, destructive!)"
  echo "  run                Start / restart the OpenVPN container"
  echo "  list               List current clients"
  echo "  generate <name>    Generate a client cert and download the .ovpn file"
  echo "  revoke <name>      Revoke a client cert"
  exit 1
}

[ $# -lt 1 ] && usage

COMMAND=$1

case "$COMMAND" in
  init)
    echo "WARNING: This will destroy existing VPN data. Press Ctrl-C to cancel, Enter to continue."
    read -r
    ssh "$BOXNAME" "sudo rm -rf $OPENVPN_DATA && docker run --rm -v $OPENVPN_DATA:/etc/openvpn kylemanna/openvpn ovpn_genconfig -d -N -u $OPENVPN_ADDRESS"
    ssh -t "$BOXNAME" "docker run --rm -v $OPENVPN_DATA:/etc/openvpn -it kylemanna/openvpn ovpn_initpki"
    ;;

  run)
    ssh "$BOXNAME" bash -s <<EOF
      set -euo pipefail
      docker stop $OPENVPN_CONTAINER_NAME || true
      docker rm $OPENVPN_CONTAINER_NAME || true
      docker run -v $OPENVPN_DATA:/etc/openvpn -d -p 1194:1194/udp --cap-add=NET_ADMIN --name $OPENVPN_CONTAINER_NAME kylemanna/openvpn
      echo "VPN container started."
EOF
    ;;

  list)
    ssh "$BOXNAME" bash -s <<EOF
      docker run -v $OPENVPN_DATA:/etc/openvpn --rm kylemanna/openvpn ovpn_listclients
EOF
    ;;

  generate)
    [ $# -lt 2 ] && { echo "Error: generate requires a client name."; usage; }
    CLIENTNAME=$2
    ssh -t "$BOXNAME" "docker run -v $OPENVPN_DATA:/etc/openvpn --rm -it kylemanna/openvpn easyrsa build-client-full $CLIENTNAME nopass"
    ssh "$BOXNAME" bash -s <<EOF
      set -euo pipefail
      docker run -v $OPENVPN_DATA:/etc/openvpn --rm kylemanna/openvpn ovpn_getclient $CLIENTNAME > ~/$CLIENTNAME.ovpn
      sed -i 's/redirect-gateway def1/#redirect-gateway def1/' ~/$CLIENTNAME.ovpn
      echo "# allow-pull-fqdn" >> ~/$CLIENTNAME.ovpn
      echo "route-nopull" >> ~/$CLIENTNAME.ovpn
      echo "route $OPENVPN_ROUTE 255.255.0.0" >> ~/$CLIENTNAME.ovpn
      echo "Client config written to ~/$CLIENTNAME.ovpn"
EOF
    echo "Downloading $CLIENTNAME.ovpn to ~/Downloads..."
    rsync "$BOXNAME":~/"$CLIENTNAME.ovpn" ~/Downloads/
    echo "Saved to ~/Downloads/$CLIENTNAME.ovpn"
    ;;

  revoke)
    [ $# -lt 2 ] && { echo "Error: revoke requires a client name."; usage; }
    CLIENTNAME=$2
    ssh "$BOXNAME" bash -s <<EOF
      set -euo pipefail
      docker run -v $OPENVPN_DATA:/etc/openvpn --rm kylemanna/openvpn easyrsa revoke $CLIENTNAME
      docker run -v $OPENVPN_DATA:/etc/openvpn --rm kylemanna/openvpn easyrsa gen-crl
      sudo cp $OPENVPN_DATA/pki/crl.pem $OPENVPN_DATA/crl.pem
      echo "Client $CLIENTNAME revoked."
EOF
    ;;

  *)
    echo "Unknown command: $COMMAND"
    usage
    ;;
esac
