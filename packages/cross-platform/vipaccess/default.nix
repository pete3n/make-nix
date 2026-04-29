{ pkgs }:

let
  python-vipaccess = pkgs.python313Packages.buildPythonApplication {
    pname = "python-vipaccess";
    version = "0.14.2";

    src = pkgs.fetchFromGitHub {
      owner = "pete3n";
      repo = "python-vipaccess";
      rev = "9f49da31664e31608b2604e12768995368f7dfc7";
      hash = "sha256-J9HKwkJStTZ6zm4u100+DSuxIbn4/kiGu/uAE8P/ALg=";
    };

    pyproject = true;
    build-system = with pkgs.python313Packages; [ setuptools ];

    propagatedBuildInputs = with pkgs.python313Packages; [
      pycryptodome
      oath
      requests
    ];

    doCheck = false;
    pythonImportsCheck = [ "vipaccess" ];

    meta = with pkgs.lib; {
      description = "Free software implementation of Symantec VIP Access";
      homepage = "https://github.com/pete3n/python-vipaccess";
      license = licenses.asl20;
      mainProgram = "vipaccess";
    };
  };

in pkgs.writeShellApplication {
  name = "vip-provision-yubikey";

  runtimeInputs = [
    python-vipaccess
    pkgs.bubblewrap
    pkgs.yubikey-manager
  ];

  text = builtins.readFile ./vip-provision-yubikey.sh;
}
