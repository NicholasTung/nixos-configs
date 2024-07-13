{ config, pkgs, lib, ... }: {
	imports = 
		[ # Include the results of the hardware scan.
			./hardware-configuration.nix
		];

  boot.loader.systemd-boot.enable = true;
  
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  
  time.timeZone = "America/New_York";
  
  networking.hostName = "agrotera";
  
  ## from https://xeiaso.net/blog/paranoid-nixos-2021-07-18/
  security.sudo.execWheelOnly = true;
  
  nix.allowedUsers = [ "@wheel" ];

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
	 
	 openssh.authorizedKeys.keys = 
		 [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILRpk45aMtMZY+9MAysPHaWZA3hEPsB2feQUUz3Cn1mU mbp"
		 ];
	};

  environment.defaultPackages = lib.mkForce [];
  environment.systemPackages = with pkgs [
	  git
	  vim
	  rg
	  mergerfs
	  rsync
    agenix.packages.${pkgs.system}.agenix
  ];

  networking.firewall.enable = true;
	networking.firewall.allowedTCPPorts = [ 22 ];

  ## boot disk configuration
	fileSystems."/" =
    { device = "rpool/root";
      fsType = "zfs";
    };

  fileSystems."/nix" =
    { device = "rpool/nix";
      fsType = "zfs";
    };

  fileSystems."/home" =
    { device = "rpool/safe/home";
      fsType = "zfs";
    };
  
  fileSystems."/persist" =
    { device = "rpool/safe/persist";
      fsType = "zfs";
      neededForBoot = true;
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/E9D7-CEAC";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };

  swapDevices = [ { device = "/dev/disk/by-uuid/5c4deab1-b540-4dc7-a64c-c2817aa59488"; } ];
  
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
  
  boot.initrd.kernelModules = [ "zfs" ];
  boot.initrd.systemd.enable = true;
  boot.initrd.systemd.services.rollback = {
    description = "Rollback root filesystem to a pristine state on boot";
    wantedBy = [
      # "zfs.target"
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

  fileSystems."/mnt/disks/internal" =
		{ device = "/dev/disk/by-uuid/3b5c2d01-78ad-4a31-993c-0d4b6d5edef5";
			fsType = "ext4";
		};
	fileSystems."/mnt/disk/wd" =
		{ device = "/dev/disk/by-uuid/507c5918-f81f-470a-9bac-36d4f6b883d2";
			fsType = "ext4";
		};
	fileSystems."/mnt/disk/seagate" =
		{ device = "/dev/disk/by-uuid/5440af94-46b8-4108-8aff-e365173b052e";
			fsType = "ext4";
		};
	fileSystems."/storage" = 
		{ device = "/mnt/disks/*";
		  fsType = "fuse.mergerfs";
		  options = [
			  "defaults"
			  "cache.files=off"
			  "moveonenospc=true"
			  "dropcacheonclose=true"
			  "minfreespace=200G"
			 ];
		 };

  environment.persistence."/persist" = {
		directories = 
			# recommended by the NixOS Manual
			[ "/var/lib/nixos"
				"/var/lib/systemd"
				"/var/log/journal"
				
				# /var/tmp is supposed to be persisted between boots, apparently
				"/var/tmp"
			];
		files = 
			# recommended by the NixOS Manual
			[ "/etc/zfs/zpool.cache"
				"/etc/machine-id"
				
				# for ssh service
				"/etc/ssh/ssh_host_ed25519_key"
	      "/etc/ssh/ssh_host_ed25519_key.pub"
	      "/etc/ssh/ssh_host_rsa_key"
	      "/etc/ssh/ssh_host_rsa_key.pub"
			];
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
  system.stateVersion = "${config.system.nixos.release}"; # Did you read the comment?
}