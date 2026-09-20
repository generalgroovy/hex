New-NetFirewallRule `
  -DisplayName "FLUX Farflow UDP 24872" `
  -Direction Inbound `
  -Protocol UDP `
  -LocalPort 24872 `
  -Action Allow