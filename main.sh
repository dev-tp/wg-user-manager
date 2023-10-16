#!/bin/sh

function create {
  if [ ! -f wg.db ]; then
sqlite3 wg.db << EOF
CREATE TABLE user (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  profile TEXT,
  address TEXT,
  private_key TEXT,
  public_key TEXT
);
EOF
  fi

  wg genkey | tee private.key | wg pubkey > public.key

  private_key=$(cat private.key)
  public_key=$(cat public.key)

  read -p 'Who is going to use this connection? ' profile
  read -p 'What address will be assigned (e.g. 10.0.0.x)? ' address

cat << EOF > CTL.conf
[Interface]
Address = $address/32
PrivateKey = $private_key

[Peer]
AllowedIPs = 0.0.0.0/1, 128.0.0.0/1
Endpoint = $ENDPOINT
PublicKey = $PUBLIC_KEY
EOF

  zip config.zip CTL.conf
  rm CTL.conf

  # Perhaps give the option to create a directory whenever multiple users are
  # added sequentially
  # mkdir -p "$profile"
  # mv config.zip "$profile"

sqlite3 wg.db << EOF
INSERT INTO user (profile, address, private_key, public_key)
VALUES ('$profile', '$address', '$private_key', '$public_key');
EOF

  rm *.key
}

# TODO Delete profile
function delete {
  echo 'delete'
}

function list {
  sqlite3 -line wg.db 'SELECT * FROM user;'
}

function print {
cat << EOF
[Interface]
Address = 10.0.0.1/24
ListenPort = 51820
PrivateKey = $PRIVATE_KEY
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eno1 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eno1 -j MASQUERADE

EOF

  sqlite3 wg.db 'SELECT profile, address, public_key FROM user' | {
    while IFS='|' read -ra row; do
      echo "# ${row[0]}"
      echo '[Peer]'
      echo "Address = ${row[1]}/32"
      echo "PublicKey = ${row[2]}"
      echo
    done
  }
}

if [ -f .env ]; then
  export $(cat .env | xargs)
else
  echo 'Please create .env file first.'
  exit
fi

create
list
print
