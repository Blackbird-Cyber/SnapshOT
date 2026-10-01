# SnapshOT: the vendored tool wrappers live in /opt/snapshot/bin (each wrapper
# sets its tool's runtime up and execs the real program). Append the dir so the
# OS's own commands always win and nothing shadows /usr/bin.
case ":$PATH:" in
  *":/opt/snapshot/bin:"*) ;;
  *) PATH="$PATH:/opt/snapshot/bin" ;;
esac
export PATH
