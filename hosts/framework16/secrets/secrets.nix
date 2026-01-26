let
  pete_yk_pri = "age1yubikey1q2hzhr0yekk766v76s5gpsv45t2hl4p644e7w6v77fl30n6qy9keuctu0z6";
  pete_yk_bak = "age1yubikey1qdxcmeztxrax00vx5gnyteacgqn7jmdc3qnuvts82rkg2zwwmuccc85afcz";
in
{
  "wifi/p22-lan-2g.conf.age".publicKeys = [
    pete_yk_pri
    pete_yk_bak
  ];

  "wifi/p22-lan-5g.conf.age".publicKeys = [
    pete_yk_pri
    pete_yk_bak
  ];
}
