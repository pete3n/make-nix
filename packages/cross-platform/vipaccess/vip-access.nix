{
  pkgs,
}:

pkgs.python313Packages.buildPythonApplication {
  pname = "python-vipaccess";
  version = "0.14.2";

  src = pkgs.fetchFromGitHub {
    owner = "pete3n";
    repo = "python-vipaccess";
    rev = "9f49da31664e31608b2604e12768995368f7dfc7";
    hash = "sha256-J9HKwkJStTZ6zm4u100+DSuxIbn4/kiGu/uAE8P/ALg=";
  };

  pyproject = true; # Use pypa
  build-system = with pkgs.python313Packages; [ setuptools ];

  propagatedBuildInputs = with pkgs.python313Packages; [
    pycryptodome # AES-128-CBC decryption of the provisioning response
    oath # TOTP/HOTP computation
    requests # HTTPS to Symantec endpoints during provisioning only
  ];

  # Tests require live network access to Symantec's servers.
  # They cannot run inside the Nix build sandbox.
  doCheck = false;

  # Smoke-test that the package imports cleanly. This runs inside the sandbox
  # and catches packaging errors (missing files, bad entry points) without
  # needing network access.
  pythonImportsCheck = [ "vipaccess" ];

  meta = with pkgs.lib; {
    description = "Nix package for dlenski's Symantec VIP Access implementation";
    homepage = "https://github.com/pete3n/python-vipaccess";
    license = licenses.asl20;
    mainProgram = "vipaccess";
  };
}
