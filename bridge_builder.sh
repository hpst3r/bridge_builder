#!/bin/bash

# bond interface/connection name
bond_name="bond0"

# interfaces to slave to bond
interfaces=("enp1s0f0" "enp1s0f1" "enp1s0f2" "enp1s0f3")

# VLANs to add
vlans=(254 244 243 100 1925 1935)

bond_exists=$(nmcli con | grep -v "$bond_name")

if [[ ! "$bond_exists" ]]; then

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
  
  connection_is_mastered=$(nmcli con sh "$interface" | grep -E "master:.*[^-]$")
  
  if [[ ! "$connection_is_mastered" ]]; then

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

  vlan_exists=$(nmcli con | grep "$vlan_name")

  if [[ ! "$vlan_exists" ]]; then

    echo "VLAN ${vlan} connection '${vlan_name}' does not exist. Creating it and its bridge."

    bridge_name="bridge${vlan}"
  
    # add a disassociated bridge
    sudo nmcli con add type bridge \
      con-name "$bridge_name" \
      ifname "$bridge_name" \
      ipv4.method disabled \
      ipv6.method ignore

    echo "Created bridge '${bridge_name}'."
  
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
