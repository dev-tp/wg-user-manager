#!/bin/bash

function create {
  local private_key=$(wg genkey)
  local public_key=$(echo $private_key | wg pubkey)

  local address profile
  read -p 'Who is going to use this connection? ' profile
  read -p 'What address will be assigned (e.g. 10.0.0.x)? ' address

  generate_config_file

  sqlite3 wg.db <<EOF
INSERT INTO user (profile, address, private_key, public_key)
VALUES ('$profile', '$address', '$private_key', '$public_key');
EOF
}

function delete {
  list

  echo
  read -p 'Enter the id you want to delete: ' id

  if [[ $id =~ ^[0-9]+$ ]]; then
    sqlite3 wg.db "UPDATE user SET deleted = CURRENT_TIMESTAMP WHERE id = $id"
  fi
}

function edit {
  list

  echo
  read -p 'Enter the id you want to edit: ' id

  if [[ $id =~ ^[0-9]+$ ]]; then
    sqlite3 wg.db "SELECT profile, address FROM user WHERE id = $id" | {
      while IFS='|' read -ra row; do
        read -p "Enter profile [${row[0]}]: " profile </dev/tty

        if [ -z "$profile" ]; then
          profile=${row[0]}
        fi

        read -p "Enter address [${row[1]}]: " address </dev/tty

        if [ -z "$address" ]; then
          address=${row[1]}
        fi

        read -p 'Would you like to regenerate key pair? [y/N] ' regenerate </dev/tty

        if [[ "$regenerate" != 'y' ]]; then
          sqlite3 wg.db "UPDATE user SET profile = '$profile', address = '$address' WHERE id = $id"
        else
          local private_key=$(wg genkey)
          local public_key=$(echo $private_key | wg pubkey)

          sqlite3 wg.db <<EOF
UPDATE
  user
SET
  profile = '$profile',
  address = '$address',
  private_key = '$private_key',
  public_key = '$public_key'
WHERE
  id = $id;
EOF
        fi
      done
    }
  fi
}

function generate {
  list

  echo
  read -p 'Enter id to generate config file: ' id

  if [[ $id =~ ^[0-9]+$ ]]; then
    sqlite3 wg.db "SELECT address, private_key FROM user WHERE id = $id" | {
      while IFS='|' read -ra row; do
        local address=${row[0]}
        local private_key=${row[1]}

        generate_config_file
      done
    }
  fi
}

function generate_config_file {
  cat <<EOF >$CONFIG_FILE_NAME
[Interface]
Address = $address/32
PrivateKey = $private_key

[Peer]
AllowedIPs = 0.0.0.0/1, 128.0.0.0/1
Endpoint = $ENDPOINT
PublicKey = $PUBLIC_KEY
EOF

  zip config.zip $CONFIG_FILE_NAME
  rm $CONFIG_FILE_NAME
}

function list {
  sqlite3 -header -column wg.db <<EOF
SELECT
  id,
  address,
  profile,
  public_key
FROM
  user
WHERE
  deleted IS NULL
ORDER BY
  address DESC
EOF
}

function print {
  cat <<EOF
[Interface]
Address = 10.0.0.1/24
ListenPort = 51820
PrivateKey = $PRIVATE_KEY
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eno1 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eno1 -j MASQUERADE

EOF

  sqlite3 wg.db 'SELECT profile, address, public_key FROM user WHERE deleted IS NULL ORDER BY address DESC' | {
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

if [ ! -f wg.db ]; then
  sqlite3 wg.db <<EOF
CREATE TABLE user (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  profile TEXT,
  address INTEGER,
  private_key TEXT,
  public_key TEXT,
  added INTEGER DEFAULT CURRENT_TIMESTAMP,
  deleted INTEGER
);
EOF
fi

echo 'WireGuard User Manager'

while true; do
  echo
  echo 'c. create'
  echo 'd. delete'
  echo 'e. edit'
  echo 'g. generate'
  echo 'l. list'
  echo 'p. print'
  echo 'q. quit'
  echo

  read -p '>>> ' option

  case $option in
  c) create ;;
  d) delete ;;
  e) edit ;;
  g) generate ;;
  l) list ;;
  p) print ;;
  q) exit ;;
  esac
done
