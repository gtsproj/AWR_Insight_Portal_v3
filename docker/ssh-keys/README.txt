Place SSH private key files in this directory for SAR server connections.

Example:
  id_rsa           (default OpenSSH private key)
  app_server_key   (named key for a specific server)

Keys in this directory are mounted read-only into the DAR Portal container
at /app/ssh-keys/. Reference them in Settings → SAR Source → SSH Key File
using the path: /app/ssh-keys/<filename>

SECURITY: This directory contains private keys — do not commit to version
control. The .gitignore excludes docker/ssh-keys/*.
