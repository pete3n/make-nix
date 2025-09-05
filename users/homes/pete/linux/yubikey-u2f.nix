{ pkgs, makeNixAttrs, ... }:
{
  # Imperative creation of Yubikey auth file
  # p22 origin and appid
  home.file."/home/${makeNixAttrs.user}/.config/Yubico/u2f_keys" = {
    source = "${pkgs.writeText "${makeNixAttrs.user}-u2f-auth-file" ''${makeNixAttrs.user}:jPXIHluUKJNDbiCSQ5+DRfMrG+ZNqMyQXTHSyByi5XHSXHNhZC2CduqlqNOIutx2NIc8Qhn2omlCFpcOoDjukw==,FQlfOdBDXUlixODcx+4gDsFIyLaX21KWqkEmbVx3ny7iwJpL43O2BRMAcArBJWJ/tEsz2/lxI/gZk7Dn9093vA==,es256,+presence:4a218pdZXDWigFWVcGDubvTbdAN9cAlp9+r0CPezvDojRPeou4j1m6vv4ZqW70jzNhAd9HD4gV0ykhC4Uoxi0A==,ftm749QLZ7sgH9ITIyb+f3Wn4BXDjK32+qIMlkfkOnMZ8On6GWBteaITzdCZ6PRzbTCQPZ6TC+ylGLw/rn0Ewg==,es256,+presence''}";
  };
}
