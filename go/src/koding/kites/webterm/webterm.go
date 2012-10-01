package main

import (
	"koding/config"
	"koding/tools/dnode"
	"koding/tools/kite"
	"koding/tools/log"
	"koding/tools/pty"
	"koding/tools/utils"
	"os"
	"strconv"
	"strings"
	"syscall"
	"unicode/utf8"
)

type WebtermServer struct {
	session *kite.Session
	remote  dnode.Remote
	pty     *pty.PTY
	process *os.Process
}

func main() {
	utils.DefaultStartup("webterm kite", true)

	if config.Current.UseWebsockets {
		runWebsocket()
		return
	}

	kite.Run("webterm", func(session *kite.Session, method string, args interface{}) (interface{}, error) {
		if method == "createServer" {
			server := &WebtermServer{session: session}
			server.remote = args.(map[string]interface{})
			session.CloseOnDisconnect = append(session.CloseOnDisconnect, server)
			return server, nil
		}
		return nil, &kite.UnknownMethodError{method}
	})
}

func (server *WebtermServer) GetSessions(callback dnode.Callback) {
	dir, err := os.Open("/var/run/screen/S-" + server.session.User)
	if err != nil {
		if os.IsNotExist(err) {
			callback(map[string]string{})
			return
		}
		panic(err)
	}
	names, err := dir.Readdirnames(0)
	if err != nil {
		panic(err)
	}
	sessions := make(map[string]string)
	for _, name := range names {
		parts := strings.SplitN(name, ".", 2)
		sessions[parts[0]] = parts[1]
	}
	callback(sessions)
}

func (server *WebtermServer) CreateSession(name string, sizeX, sizeY float64) {
	server.runScreen([]string{"-S", name}, sizeX, sizeY)
}

func (server *WebtermServer) JoinSession(sessionId, sizeX, sizeY float64) {
	server.runScreen([]string{"-x", strconv.Itoa(int(sessionId))}, sizeX, sizeY)
}

func (server *WebtermServer) runScreen(args []string, sizeX, sizeY float64) {
	if server.pty != nil {
		panic("Trying to open more than one session.")
	}

	command := []string{"/bin/bash"}
	// command = append(command, args...)

	pty := pty.New()
	server.pty = pty
	server.SetSize(sizeX, sizeY)

	cmd := server.session.CreateCommand(command)
	pty.AdaptCommand(cmd)
	err := cmd.Start()
	if err != nil {
		panic(err)
	}
	server.process = cmd.Process

	go func() {
		defer log.RecoverAndLog()

		cmd.Wait()
		pty.Master.Close()
		pty.Slave.Close()
		server.pty = nil
		server.process = nil
		server.remote["sessionEnded"].(dnode.Callback)()
	}()

	go func() {
		defer log.RecoverAndLog()

		buf := make([]byte, 1<<12, (1<<12)+4)
		for {
			n, err := pty.Master.Read(buf)
			for {
				r, _ := utf8.DecodeLastRune(buf[:n])
				if r != utf8.RuneError {
					break
				}
				pty.Master.Read(buf[n : n+1])
				n += 1
			}
			server.remote["output"].(dnode.Callback)(string(buf[:n]))
			if err != nil {
				break
			}
		}
	}()

	server.remote["sessionStarted"].(dnode.Callback)()
}

func (server *WebtermServer) Input(data string) {
	if server.pty != nil {
		server.pty.Master.Write([]byte(data))
	}
}

func (server *WebtermServer) ControlSequence(data string) {
	if server.pty != nil {
		server.pty.MasterEncoded.Write([]byte(data))
	}
}

func (server *WebtermServer) SetSize(x, y float64) {
	if server.pty != nil {
		server.pty.SetSize(uint16(x), uint16(y))
	}
}

func (server *WebtermServer) Close() error {
	if server.process != nil {
		server.process.Signal(syscall.SIGHUP)
	}
	return nil
}
