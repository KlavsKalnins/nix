# notes
## nixos-rebuild switch // to apply changes
## nixos-rebuild to create a VM using this configuration and run the result


# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Riga";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "lv";
    variant = "";
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.kaste = {
    isNormalUser = true;
    description = "kaste";
    extraGroups = [ "networkmanager" "wheel" ];
    openssh.authorizedKeys.keys = [
      # Add your public key if you want to SSH *into* this server
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBAgYRyANen+i2kT+kDBx7M/LjwIK8zaua0Y2gzVPjKU nixos-server"
    ];
    packages = with pkgs; [];
  };

  # Enable automatic login for the user.
  services.getty.autologinUser = "kaste";

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
  #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
  #  wget
  git
  dotnet-sdk_9
  postgresql_16
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:
  system.activationScripts.setupSSH = ''
    mkdir -p /home/kaste/.ssh
    cp /etc/ssh/kaste /home/kaste/.ssh/kaste
    chmod 600 /home/kaste/.ssh/kaste
    chown -R kaste:kaste /home/kaste/.ssh

    echo "Host github.com
      IdentityFile /home/kaste/.ssh/kaste
      StrictHostKeyChecking no
      User git" > /home/kaste/.ssh/config
    chmod 600 /home/kaste/.ssh/config
  '';

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_15;  # Choose version as needed
    authentication = ''
      local   all             all                                     trust
      host    all             all             127.0.0.1/32            md5
      host    all             all             ::1/128                 md5
    '';
    initialScript = pkgs.writeText "init.sql" ''
      CREATE USER kaste WITH PASSWORD 'your-secure-password';
      CREATE DATABASE apidb OWNER kaste;
    '';
  };

  system.activationScripts.gitClone = ''
    mkdir -p /home/kaste/myapp
    chown kaste:kaste /home/kaste/myapp
    sudo -u kaste git clone https://your-repo-url.git /home/kaste/myapp || true
  '';

  systemd.services.dotnet-api = {
    description = "My .NET API";
    after = [ "network.target" "postgresql.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      User = "kaste";
      WorkingDirectory = "/home/kaste/myapp";
      ExecStart = "${pkgs.dotnet-sdk_8}/bin/dotnet run";
      Restart = "always";
      Environment = "ASPNETCORE_ENVIRONMENT=Production";
    };
  };

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
  services.openssh.passwordAuthentication = true;

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 22 ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?

}
