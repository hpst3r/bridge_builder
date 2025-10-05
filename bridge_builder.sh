#!/bin/bash

# bond interface/connection name
bond_name="bond0"

# interfaces to slave to bond
interfaces=("enp1s0f0" "enp1s0f1" "enp1s0f2" "enp1s0f3")

# VLANs to add
vlans=(2 11 12 200 254 901 999)

nmcli con | grep -q "$bond_name"
bond_exists=$?

if [[ bond_exists -ne 0 ]]; then

  echo "Bond '${bond_name}' was not found - creating it."

  # create the bond
  sudo nmcli con add type bond \
    con-name "$bond_name" \
    ifname "$bond_name" \
    bond.options "mode=802.3ad" \
    ipv4.method disabled \
    ipv6.method disabled

else

  echo "Bond '${bond_name}' already exists - no changes were made."

fi

# slave physical interfaces to the bond
for interface in "${interfaces[@]}"; do

  nmcli con sh "$interface" 2> /dev/null | grep -qE "$interface"
  interface_exists=$?

  if [[ interface_exists -ne 0 ]]; then
  
    echo "Connection '${interface}' does not exist. Creating new connection for interface '${interface}'."

    sudo nmcli con add type ethernet ifname "$interface" con-name "$interface" save yes autoconnect yes

  fi

  nmcli con sh "$interface" | grep -qE "master:[[:space:]]*${bond_name}[[:space:]]*$"
  connection_mastered=$?

  if [[ connection_mastered -ne 0 ]]; then

    echo "Interface '${interface}' is not mastered by bond '${bond_name}' - slaving it."

    sudo nmcli con mod "$interface" \
      slave-type bond \
      master "$bond_name"

    echo "Slaved interface '${interface}' to bond '${bond_name}'."

  else

    echo "Interface '${interface}' was already mastered by bond '${bond_name}' - no changes were made."

  fi

done

# create bridges and slave requested VLANs to them
for vlan in "${vlans[@]}"; do

  vlan_name="vlan${vlan}"

  nmcli con | grep -q "$vlan_name"
  vlan_exists=$?

  bridge_name="bridge${vlan}"

  nmcli con | grep -q "$bridge_name"
  bridge_exists=$?

  if [[ bridge_exists -ne 0 ]]; then

    echo "Bridge ${vlan} connection '${bridge_name}' does not exist. Creating it."

    sudo nmcli con add type bridge \
      con-name "$bridge_name" \
      ifname "$bridge_name" \
      ipv4.method disabled \
      ipv6.method ignore

    echo "Created bridge '${bridge_name}'."

  else

    echo "Bridge ${vlan} connection '${bridge_name}' already exists - no changes were made."

  fi

  if [[ vlan_exists -ne 0 ]]; then

    echo "VLAN ${vlan} connection '${vlan_name}' does not exist. Creating it."

    # add desired vlan to bond, slave it to the bridge
    sudo nmcli con add type vlan \
      con-name "$vlan_name" \
      ifname "$bond_name"."$vlan" \
      dev "$bond_name" \
      id "$vlan" \
      master "$bridge_name" \
      slave-type bridge

    echo "Created VLAN ${vlan} connection '${vlan_name}' as slave to bridge '${bridge_name}'."

  else

    echo "VLAN ${vlan} connection '${vlan_name}' already exists - no changes were made."

  fi

done
