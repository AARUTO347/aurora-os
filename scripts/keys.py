import socket, sys, time
sock, keys = sys.argv[1], sys.argv[2:]
c = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
c.connect(sock)
for k in keys:
    c.sendall(("sendkey " + k + "\n").encode())
    time.sleep(0.06)
time.sleep(0.5)
c.close()
