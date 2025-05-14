# nix

QEMU

## run on mac

mkdir nixos-vm && cd nixos-vm
nano configuration.nix

nix-shell -p nixos-rebuild
nixos-rebuild build-vm -I nixos-config=./configuration.nix
./result/bin/run-*-vm

## if needed remove nix

### 1. Remove the /nix volume

sudo diskutil apfs deleteVolume /nix

### 2. Remove the mount config

sudo sed -i '' '/^nix$/d' /etc/synthetic.conf

### 3. Remove the launch daemon if it exists

sudo rm -f /Library/LaunchDaemons/org.nixos.nix-daemon.plist

### 4. Delete Nix-related user files

sudo rm -rf /nix ~/.nix* ~/.config/nixpkgs ~/.local/state/nix

### 5. Reboot your system (important to unmount cleanly)

sudo reboot


# build and qemu

brew install qemu

nixos-rebuild build-vm -I nixos-config=./configuration.nix

cd ./result
./bin/run-*-vm

// qemu-system-x86_64 -drive file=./result/nixos.qcow2,format=qcow2 -m 2048 -smp 2 -net nic -net user
