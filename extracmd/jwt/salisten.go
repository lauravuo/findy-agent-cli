package jwt

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"github.com/findy-network/findy-agent-api/grpc/agency"
	"github.com/findy-network/findy-agent-cli/cmd"
	"github.com/findy-network/findy-agent/agent/utils"
	"github.com/findy-network/findy-agent/grpc/client"
	"github.com/lainio/err2"
	"github.com/spf13/cobra"
)

// userCmd represents the user command
var saListenCmd = &cobra.Command{
	Use:   "salisten",
	Short: "SA listen command for JWT gRPC",
	Long: `
`,
	PreRunE: func(c *cobra.Command, args []string) (err error) {
		return cmd.BindEnvs(envs, "")
	},
	RunE: func(c *cobra.Command, args []string) (err error) {
		defer err2.Return(&err)

		if cmd.DryRun() {
			return nil
		}
		c.SilenceUsage = true

		addr := fmt.Sprintf("%s:%d", cmdData.APIService, cmdData.Port)
		conn, err := client.NewClient(cmdData.CaDID, addr)
		err2.Check(err)

		defer conn.Close()

		ctx, cancel := context.WithCancel(context.Background())
		defer cancel() // for server side stops, for proper cleanup

		// Handle graceful shutdown
		intCh := make(chan os.Signal, 1)
		signal.Notify(intCh, syscall.SIGTERM)
		signal.Notify(intCh, syscall.SIGINT)

		ch, err := client.Listen(ctx, &agency.ClientID{Id: utils.UUID()})
		err2.Check(err)

	loop:
		for {
			select {
			case status, ok := <-ch:
				if !ok {
					fmt.Println("closed from server")
					break loop
				}
				fmt.Println("listen status:", status.ClientId, status.Notification.TypeId, status.Notification.Id)
				if status.Notification.TypeId == agency.Notification_ACTION_NEEDED_PING {
					ctx := context.Background()
					c := agency.NewAgentClient(conn)
					cid, err := c.Give(ctx, &agency.Answer{
						Id:       status.Notification.Id,
						ClientId: status.ClientId,
						Ack:      true,
						Info:     "cmd salisten says hello!",
					})
					err2.Check(err)
					fmt.Printf("ping answer (%s) send to client:%s\n", status.Notification.Id, cid.Id)
				}
			case <-intCh:
				cancel()
				fmt.Println("interrupted by user, cancel() called")
			}
		}

		return nil
	},
}

func init() {
	defer err2.Catch(func(err error) {
		fmt.Println(err)
	})

	jwtCmd.AddCommand(saListenCmd)
}
