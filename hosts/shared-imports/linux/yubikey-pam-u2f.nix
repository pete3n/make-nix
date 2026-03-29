{ ... }:
{
  security.pam.u2f = {
    enable = true;
    settings = {
      origin = "pam://p22";
      appid  = "pam://p22";
      cue    = true;
      debug  = false;
    };
  };
}
