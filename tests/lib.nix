{
  # A systemd service answering HTTP on a port, standing in for a real service.
  webServer = pkgs: port: {
    wantedBy = [ "multi-user.target" ];
    serviceConfig.ExecStart = "${pkgs.python3}/bin/python3 -m http.server ${toString port}";
  };
}
