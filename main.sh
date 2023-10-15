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

  printf "Who is going to use this connection? "
  read profile

  printf "What address will be assigned (e.g. 10.0.0.x)? "
  read address

cat << EOF > CTL.conf
[Interface]
Address = $address/32
PrivateKey = $private_key

[Peer]
AllowedIPs = 0.0.0.0/1, 128.0.0.0/1
Endpoint = office.countrywidetriallawyers.com:51820
PublicKey = GzQYjKqA0bsyCC6e3N8zz2kShGMsLP9SHZgWz4ezgwM=
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

# TODO Print generated wg0.conf file
function print {
  echo 'print'
}

create
list
