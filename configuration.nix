{ config, pkgs, lib, agenix, ... }: {
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./services
    ];

  boot.loader.systemd-boot.enable = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  time.timeZone = "America/New_York";

  networking.hostName = "agrotera";
  networking.hostId = "00000001";

  ## from https://xeiaso.net/blog/paranoid-nixos-2021-07-18/
  security.sudo.execWheelOnly = true;

  security.sudo.wheelNeedsPassword = false;

  nix.settings.allowed-users = [ "@wheel" ];

  ## from https://xeiaso.net/blog/paranoid-nixos-2021-07-18/
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
    allowSFTP = false; # Don't set this if you need sftp
    extraConfig = ''
      AllowTcpForwarding yes
      X11Forwarding no
      AllowAgentForwarding no
      AllowStreamLocalForwarding no
      AuthenticationMethods publickey
    '';
  };

  # disable creation of new users at runtime
  users.mutableUsers = false;
  users.users.nicholast = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];

    # disables logging in to this user using a password altogether
    # this defaults to null, but i'll state it anyway
    # see https://search.nixos.org/options?channel=24.05&show=users.users.%3Cname%3E.hashedPassword
    hashedPassword = null;

    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILRpk45aMtMZY+9MAysPHaWZA3hEPsB2feQUUz3Cn1mU mbp"
    ];
  };

  environment.defaultPackages = lib.mkForce [ ];
  environment.systemPackages = with pkgs; [
    git
    vim
    ripgrep
    mergerfs
    rsync
    agenix.packages.${pkgs.system}.agenix
  ];

  ## boot disk configuration
  fileSystems."/" = {
    device = "rpool/root";
    fsType = "zfs";
  };

  fileSystems."/nix" = {
    device = "rpool/nix";
    fsType = "zfs";
  };

  fileSystems."/home" = {
    device = "rpool/safe/home";
    fsType = "zfs";
  };

  fileSystems."/persist" = {
    device = "rpool/safe/persist";
    fsType = "zfs";
    neededForBoot = true;
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/0632-1869";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  swapDevices = [
    { device = "/dev/disk/by-uuid/9ad578cd-8df9-4186-82e7-eca235f1aec8"; }
  ];

  boot.supportedFilesystems.zfs = true;
  # see https://search.nixos.org/options?channel=24.05&show=boot.zfs.forceImportRoot&from=0&size=50&sort=relevance&type=packages&query=boot.zfs
  boot.zfs.forceImportRoot = false;

  services.zfs.autoScrub.enable = true;

  # "Erase your darlings" recommends disabling the disk scheduler when
  # using ZFS in a set up where only part of the disk is ZFS.
  # However, the kernel parameter "elevator=none" has since been deprecated,
  # so I will use this udev rule from https://discourse.nixos.org/t/enable-none-in-the-i-o-scheduler/36566/3
  services.udev.extraRules = ''
    ACTION=="add|change", KERNEL=="sd[a-z]*[0-9]*|mmcblk[0-9]*p[0-9]*|nvme[0-9]*n[0-9]*p[0-9]*", ENV{ID_FS_TYPE}=="zfs_member", ATTR{../queue/scheduler}="none"
  '';

  # https://discourse.nixos.org/t/zfs-rollback-not-working-using-boot-initrd-systemd/37195/3
  boot.initrd.kernelModules = [ "zfs" ];
  boot.initrd.systemd.enable = true;
  boot.initrd.systemd.services.rollback = {
    description = "Rollback root filesystem to a pristine state on boot";
    wantedBy = [
      "initrd.target"
    ];
    after = [
      "zfs-import-rpool.service"
    ];
    before = [
      "sysroot.mount"
    ];
    path = with pkgs; [
      zfs
    ];
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    script = ''
      zfs rollback -r rpool/root@blank && echo "  >> >> rollback complete << <<"
    '';
  };

  services.sanoid = {
    enable = true;
    templates.backup = {
      hourly = 36;
      daily = 30;
      monthly = 3;
      autoprune = true;
      autosnap = true;
    };

    datasets."rpool/safe" = {
      useTemplate = [ "backup" ];
      recursive = true;
    };
  };

  fileSystems."/mnt/disks/internal" = {
    device = "/dev/disk/by-uuid/3b5c2d01-78ad-4a31-993c-0d4b6d5edef5";
    fsType = "ext4";
  };
  fileSystems."/mnt/disks/seagate" = {
    device = "/dev/disk/by-uuid/507c5918-f81f-470a-9bac-36d4f6b883d2";
    fsType = "ext4";
  };
  fileSystems."/mnt/disks/wd" = {
    device = "/dev/disk/by-uuid/5440af94-46b8-4108-8aff-e365173b052e";
    fsType = "ext4";
  };
  fileSystems."/mnt/storage" = {
    device = "/mnt/disks/*";
    fsType = "fuse.mergerfs";
    options = [
      "defaults"
      "cache.files=partial"
      "moveonenospc=true"
      "dropcacheonclose=true"
      "minfreespace=200G"
    ];
  };

  environment.persistence."/persist" = {
    directories = [
      # recommended by the NixOS Manual
      "/var/lib/nixos"
      "/var/lib/systemd"
      "/var/log/journal"

      # /var/tmp is supposed to be persisted between boots, apparently
      "/var/tmp"

      # tailscale state
      "/var/lib/tailscale"

      # system configuration
      "/etc/nixos"
    ];
    files = [
      # recommended by the NixOS Manual
      "/etc/zfs/zpool.cache"
      "/etc/machine-id"

      # for ssh service
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];
  };

  # workaround ensures that ssh keys are available when agenix tries to decrypt secrets
  # it does this by pointing directly to the keys in /persist
  # see https://github.com/ryantm/agenix/issues/45#issuecomment-1716862823
  # TODO (nicholast): not great that the persist top level directory is hard coded
  age.identityPaths = [
    "/persist/etc/ssh/ssh_host_ed25519_key"
    "/persist/etc/ssh/ssh_host_rsa_key"
  ];

  age.secrets.ts_auth.file = ./secrets/ts_auth.age;
  services.tailscale.enable = true;
  services.tailscale.authKeyFile = config.age.secrets.ts_auth.path;

  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];
  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  # nvidia things
  nixpkgs.config.allowUnfree = true;
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics.enable = true;

  hardware.nvidia = {
    # NixOS wiki
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.production;

    prime = {
      # sudo lshw -c display
      nvidiaBusId = "PCI:1:0:0";

      # somehow, no iGPU detected so disable prime
      sync.enable = false;
    };

    # keep GPU awake in headless mode
    nvidiaPersistenced = true;
  };


  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.05"; # Did you read the comment?
}
