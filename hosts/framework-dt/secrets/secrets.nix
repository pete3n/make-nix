let
  framework-dt = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO70Au6FegohwKFygshDnN9TGll69m4cc1WXMqa8tXl/ root@framework-dt";
  pete_yk_pri = "age1yubikey1q2hzhr0yekk766v76s5gpsv45t2hl4p644e7w6v77fl30n6qy9keuctu0z6";
  pete_yk_bak = "age1yubikey1qdxcmeztxrax00vx5gnyteacgqn7jmdc3qnuvts82rkg2zwwmuccc85afcz";
in
{
  "bitcoind-rpc-hmac.age".publicKeys = [
    framework-dt
    pete_yk_pri
    pete_yk_bak
  ];
}
