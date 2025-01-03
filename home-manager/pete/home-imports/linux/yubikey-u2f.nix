{ pkgs, ... }:
{
  # Declarative creation of Yubikey auth file
  home.file."/home/pete/.config/Yubico/u2f_keys" = {
    source = "${pkgs.writeText "pete-u2f-auth-file" ''
      pete:VitP/URTordhG7xWAtVoFFxZOiK8L2cUoBY9SXWROS3vWdhL6rZYm+biNYqMmvwBz0I4O09IhUVnILsdBg/P+Q==,/Jk3pOd5nUrIiVzVMHRtJ+HxS8UBkjz1BTV7zXvwRf/0tKqfEhhR8EnsZbsrD0daw4oXDwi04RWiZJS38p/6xw==,es256,+presence:+GB7k/U1qVNeiy6c6Y6jmIiY3GZRmL8KNkersUZiCLmIfS0AShb3K++7s2Lzv7Xmz594RKPuHJ1XFS7FyLH+Cg==,NWUx6LrmdphmF0m6LVnKYhsndPprfe8x3OhqCUQ06tllGoJBm694fhJ6RvTQiXSJ4fF2GqIC5LRffPQnWzG8fw==,es256,+presence
    ''}";
  };
}
