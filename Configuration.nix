# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ config, pkgs, ... }:

let
  appName = "bubblyfriends-server";
  appDir = "/home/kaste/${appName}";
  sshKeyPath = "/home/kaste/.ssh/kaste";
  githubHostKey = "github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
  repoUrl = "git@github.com:bubbly-friends/BubblyFriendsServer.git";
in
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Create the kaste group if it doesn't exist
  users.groups.kaste = {};

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Riga";

  i18n.defaultLocale = "en_US.UTF-8";

  services.xserver.xkb = {
    layout = "lv";
    variant = "";
  };

  users.users.kaste = {
    isNormalUser = true;
    description = "kaste";
    extraGroups = [ "networkmanager" "wheel" "kaste" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBAgYRyANen+i2kT+kDBx7M/LjwIK8zaua0Y2gzVPjKU nixos-server"
    ];
  };

  services.getty.autologinUser = "kaste";

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    git
    curl
    bash
    coreutils
    gnugrep
    openssh
    nodejs
    dotnet-sdk_9
    postgresql_16
  ];

  system.activationScripts = {
    sshSetup = ''
      mkdir -p /home/kaste/.ssh
      chmod 700 /home/kaste/.ssh
      chown kaste:kaste /home/kaste/.ssh
      
      # Add GitHub to known_hosts if not already present
      if ! grep -q "github.com" /home/kaste/.ssh/known_hosts 2>/dev/null; then
        echo "${githubHostKey}" >> /home/kaste/.ssh/known_hosts
        chmod 600 /home/kaste/.ssh/known_hosts
        chown kaste:kaste /home/kaste/.ssh/known_hosts
      fi

      # SSH configuration
      cat > /home/kaste/.ssh/config <<EOF
      Host github.com
        HostName github.com
        IdentityFile ~/.ssh/kaste
        IdentitiesOnly yes
        User git
      EOF
      chmod 600 /home/kaste/.ssh/config
      chown kaste:kaste /home/kaste/.ssh/config
    '';

    gitClone = {
      text = ''
        export PATH="${pkgs.git}/bin:${pkgs.openssh}/bin:${pkgs.coreutils}/bin:$PATH"
        mkdir -p ${appDir}
        chown kaste:kaste ${appDir}
        
        if [ ! -d "${appDir}/.git" ]; then
          echo "Attempting to clone repository..."
          if runuser -u kaste -- git clone ${repoUrl} ${appDir}; then
            echo "Repository cloned successfully"
          else
            echo "Failed to clone repository"
            echo "Trying again with full debug output..."
            runuser -u kaste -- env GIT_SSH_COMMAND="ssh -vvv" git clone ${repoUrl} ${appDir} || true
            exit 1
          fi
        else
          echo "Repository already exists at ${appDir}"
          echo "Pulling latest changes..."
          runuser -u kaste -- git -C ${appDir} pull origin main
        fi
      '';
      deps = ["sshSetup"];
    };
  };

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;
    authentication = ''
      local   all             all                                     trust
      host    all             all             127.0.0.1/32            md5
      host    all             all             ::1/128                 md5
    '';
    initialScript = pkgs.writeText "init.sql" ''
      CREATE USER kaste WITH PASSWORD 'postgres';
      CREATE DATABASE apidb OWNER kaste;
    '';
  };

  systemd.services.dotnet-api = {
    description = "Bubbly Friends .NET API";
    after = [ "network.target" "postgresql.service" ];
    wants = [ "postgresql.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      User = "kaste";
      WorkingDirectory = "${appDir}/BubblyFriendsServer";
      ExecStartPre = "${pkgs.dotnet-sdk_9}/bin/dotnet build";
      # ExecStart = "${pkgs.dotnet-sdk_9}/bin/dotnet run --no-build";
      ExecStart = "${pkgs.dotnet-sdk_9}/bin/dotnet ${appDir}/BubblyFriendsServer.dll";
      # or : ExecStart = "${pkgs.dotnet-sdk_9}/bin/dotnet ${appDir}/BubblyFriendsServer/BubblyFriendsServer.csproj";
      # ExecStart = "${pkgs.dotnet-sdk_9}/bin/dotnet run";
      Restart = "always";
      # Environment = [
      #   "ASPNETCORE_ENVIRONMENT=Production"
      #   "ASPNETCORE_URLS=http://0.0.0.0:8080" # Explicit port binding
      # ];
      Environment = [
        "ASPNETCORE_ENVIRONMENT=Production"
        "ASPNETCORE_URLS=http://0.0.0.0:8080 https://0.0.0.0:8080"
      ];
    };

    preStart = ''
      export PATH="${pkgs.git}/bin:${pkgs.openssh}/bin:$PATH"
      runuser -u kaste -- git -C ${appDir} pull origin main
    '';
  };

    services.fail2ban.enable = true;

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true; # Only key-based auth
      PermitRootLogin = "no";
      X11Forwarding = false;
      AllowTcpForwarding = false;
      MaxAuthTries = 6;
      LoginGraceTime = "30s";
    };
  };

    networking.firewall = {
    enable = true;
    # Open only the .NET API ports to the world
    allowedTCPPorts = [
      8080
    ];
    # Explicitly allow SSH only from trusted IPs (optional)
    allowedTCPPortRanges = [
      { from = 22; to = 22; } # SSH
      { from = 8080; to = 8080; }
    ];
  };

  system.stateVersion = "24.11";
}