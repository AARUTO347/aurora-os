import socket, sys, time
sock = sys.argv[1]
cmd = sys.argv[2]
c = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
c.connect(sock)
c.sendall((cmd + "\n").encode())
time.sleep(1.0)
c.close()
