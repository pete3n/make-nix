{ makeNixAttrs, ... }:
{
  age.secrets.githubSshKey = {
    file = ./pete3n.age;
    path = "/home/${makeNixAttrs.user}/.ssh/pete3n";
    owner = makeNixAttrs.user;
    mode = "0600";
  };
}
