package cmd

import (
	"fmt"
	"log"
	"os"

	"github.com/lainio/err2"
	"github.com/optechlab/findy-agent/cmds/agent"
	"github.com/spf13/cobra"
)

// pingCmd represents the user/service ping subcommand
var pingCmd = &cobra.Command{
	Use:   "ping",
	Short: "Command for pinging services and agents",
	Long: ` 
Tests the connection to the CA with the given wallet. If secure connection works
ok it prints the invitation. If the EA is a SA the command pings it as well when
the --sa flag is on.

Examples
	findy-cli user ping \
		--sa \
		--walletname TheNewWallet4 \
		--walletkey 6cih1cVgRH8...dv67o8QbufxaTHot3Qxp

	this pings the CA and the connected SA as well. 
	`,
	RunE: func(cmd *cobra.Command, args []string) (err error) {
		defer err2.Return(&err)

		pCmd.WalletName = cFlags.WalletName
		pCmd.WalletKey = cFlags.WalletKey
		err2.Check(pCmd.Validate())
		if !rootFlags.dryRun {
			// if error occurs in the execution, we don't show usage, only
			// the error message.
			cmd.SilenceUsage = true

			r, err := pCmd.Exec(os.Stdout)
			err2.Check(err)
			jBytes := err2.Bytes.Try(r.JSON())
			fmt.Println(string(jBytes))
		}
		return nil
	},
}

var pCmd = agent.PingCmd{}

func init() {
	defer err2.Catch(func(err error) {
		log.Println(err)
	})

	pingCmd.Flags().BoolVarP(&pCmd.PingSA, "sa", "s", false, "ping CA and connected SA (me) as well")

	// service copy
	serviceCopy := *pingCmd
	userCmd.AddCommand(pingCmd)
	serviceCmd.AddCommand(&serviceCopy)
}
