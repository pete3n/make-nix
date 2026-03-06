# Linux only packages
{ pkgs, ... }:
{
  pomodoro-timer = import ./pomodoro-timer { inherit pkgs; };
}
